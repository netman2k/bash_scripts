#!/bin/bash
#
# Name: install_docker.sh
#
# Description:
#   Installing Docker and composer
#
# Note:
#   I do not guarantee this works well. 
#   so please use this with caution.
#
declare -r PROGNAME=$(basename $0)
declare -r PROGDIR=$(readlink -m $(dirname $0))
declare -r DEFAULT_PROMETHEUS_LISTEN="0.0.0.0:4999"
declare -r DEFAULT_DATA_ROOT="/var/lib/docker"
declare -r DEFAULT_EXPERIMENTAL="true"
declare -r DEFAULT_IPV6="false"
declare -r DEFAULT_SYSTEMD_MEMLOCK_RELEASE="true"
# https://access.redhat.com/documentation/ko-kr/red_hat_enterprise_linux/6/html/performance_tuning_guide/s-memory-captun
declare -r DEFAULT_VM_MAX_MAP_COUNT=262144
declare -r DOCKER_CONFIG_DIR="/etc/docker"
declare -r DAEMON_JSON_FILE="${DOCKER_CONFIG_DIR}/daemon.json"
declare -A OPTIONS=( ["data_root"]="${DEFAULT_DATA_ROOT}"  ["metrics-addr"]="${DEFAULT_PROMETHEUS_LISTEN}" ["experimental"]="${DEFAULT_EXPERIMENTAL}" ["ipv6"]="false")

declare docker_service="enabled"

declare default_interface=$(/sbin/ip route | awk '/default/ { print $5 }')
declare systemd_version=$(systemctl --version | awk '/systemd/{print $2}')

function usage {
    cat <<- EOF
Usage: $PROGNAME [ -h ]

Optional arguments:
    -h: Help
    -d: Change default docker data directory (default, ${DEFAULT_DATA_ROOT})
    -e: Disable experimental feature
    -6: Enable IPv6 support
    -l: Disable unlimited memlock setting (default, ${DEFAULT_SYSTEMD_MEMLOCK_RELEASE})
    -m: Increase max_map_count (default, ${DEFAULT_VM_MAX_MAP_COUNT})
    -s: Disable docker service (default, enabled)
    -p: Change prometheus bind URL (default, ${DEFAULT_PROMETHEUS_LISTEN})
    -u: An account to be a member of the docker group
    -v: Enable debug mode

General usage example:

 > Set /data/docker-data as a docker data store
  $ $PROGNAME -d /data/docker-data

 > Enable metric feature for prometheus
  $ $PROGNAME -p "${DEFAULT_PROMETHEUS_LISTEN}"

 > Increase max memory map count for process
  $ $PROGNAME -m ${DEFAULT_VM_MAX_MAP_COUNT}

 > A user, admin, to be a member of the docker group 
  $ $PROGNAME -u admin
EOF

    exit 0
}

function get_pkg_manager() {
  support_pkg_mgr=( 'yum' 'apt' 'apt-get' )
  for x in ${support_pkg_mgr[@]}
  do
    which $x &> /dev/null
    if [ $? -eq 0 ];then
      pkg_mgr=$x 
      break
    fi
  done

  echo $pkg_mgr
}


function parse_arguments {
    while getopts vd:slp:m:e6u:h OPTION
    do
        case $OPTION in
            h) usage;;
            d) OPTIONS["data_root"]=$OPTARG;;
            e) OPTIONS["experimental"]="false";;
            6) OPTIONS["IPV6"]="true";;
            l) memlock_release="false";;
            s) docker_service="disabled";;
            p) OPTIONS["metrics-addr"]=$OPTARG;;
            m) max_mem_count=${OPTARG:-$DEFAULT_VM_MAX_MAP_COUNT};;
            u) docker_user=$OPTARG;;
            v) set -x;;
        esac
    done
}

function install_docker(){
  local pkg_mgr=${1}

  echo
  echo "Installing Docker..."
  echo

  if [[ $pkg_mgr =~ (apt[-get]?) ]];then
    apt-get remove docker docker-engine docker.io
    apt-get update
    apt-get install apt-transport-https ca-certificates curl software-properties-common
  elif [ $pkg_mgr = "yum" ];then
    yum remove docker docker-client docker-client-latest docker-common \
         docker-latest docker-latest-logrotate docker-logrotate docker-selinux \
         docker-engine-selinux docker-engine -y
    yum install -y yum-utils device-mapper-persistent-data lvm2
  fi

  curl -fsSL get.docker.com -o get-docker.sh
  sh get-docker.sh

}


function install_docker_compose(){
  echo
  echo "Installing Docker compose..."
  echo

  curl -L https://github.com/docker/compose/releases/download/1.19.0/docker-compose-`uname -s`-`uname -m` \
  -o /usr/local/bin/docker-compose
  curl -L https://raw.githubusercontent.com/docker/compose/1.19.0/contrib/completion/bash/docker-compose \
  -o /etc/bash_completion.d/docker-compose
  chmod +x /usr/local/bin/docker-compose
}
function set_kernel_params(){

  local -r file_net_bridge_nf_call_iptables="10-net-bridge-nf-call-iptables.conf"
  local -r file_vm_max_map_count="10-vm-max-map-count.conf"

  echo "net.bridge.bridge-nf-call-iptables = 1" > /etc/sysctl.d/$file_net_bridge_nf_call_iptables
  echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.d/$file_net_bridge_nf_call_iptables
  sysctl -p /etc/sysctl.d/$file_net_bridge_nf_call_iptables

  if [ $max_mem_count ];then
    echo "vm.max_map_count=${max_mem_count}" > /etc/sysctl.d/$file_vm_max_map_count
    sysctl -p /etc/sysctl.d/$file_vm_max_map_count
  fi

}

function set_daemon_option() {
    [ -d $DOCKER_CONFIG_DIR ] || mkdir -p $DOCKER_CONFIG_DIR
    touch $DAEMON_JSON_FILE
    echo "{" > $DAEMON_JSON_FILE
    echo -e "  \"data-root\": \"${OPTIONS[data_root]}\","         >> $DAEMON_JSON_FILE
    echo -e "  \"ipv6\": ${OPTIONS[ipv6]},"                       >> $DAEMON_JSON_FILE
    # Only available metrics-addr when experimental is on
    if [ "${OPTIONS[experimental]}" = "true" ];then
      echo -e "  \"experimental\": ${OPTIONS[experimental]},"     >> $DAEMON_JSON_FILE
      echo -e "  \"metrics-addr\": \"${OPTIONS[metrics-addr]}\""  >> $DAEMON_JSON_FILE
    fi
    echo "}" >> $DAEMON_JSON_FILE
}


function main {

    #[ ${#@} -eq 0 ] && { usage; exit 1; }

    parse_arguments "$@"
    
    [ `id -u` -ne 0 ] && { echo "The script must be run as root! (you can use sudo)"; exit 1; }

    pkg_mgr=$(get_pkg_manager)
   
    install_docker $pkg_mgr
    [ $no_docker_compose ] || install_docker_compose

    if [ $docker_user ];then
      echo
      echo "Add $USER into the docker group..."
      usermod -aG docker $USER
    fi

    set_daemon_option
    set_kernel_params
    
    if [ "${memlock_release}" = 'true' ];then
      mkdir -p /etc/systemd/system/docker.service.d/
      echo -e "[Service]\nLimitMEMLOCK=infinity" > /etc/systemd/system/docker.service.d/override.conf
      systemctl daemon-reload
    fi

    systemctl start docker
    [ "$docker_service" = "enabled" ] && systemctl enable docker
}

main "$@"

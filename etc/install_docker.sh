#!/bin/bash
#
# Name: install_docker.sh
#
# Description:
#   Installing Docker and composer
declare -r PROGNAME=$(basename $0)
declare -r PROGDIR=$(readlink -m $(dirname $0))
declare -r DEFAULT_PROMETHEUS_LISTEN="127.0.0.1:9323"
declare -r DEFAULT_DATA_ROOT="/var/lib/docker"
declare -r DEFAULT_EXPERIMENTAL="true"
declare -r DAEMON_JSON_FILE="/etc/docker/daemon.json"
declare -A OPTIONS=( ["data_root"]="${DEFAULT_DATA_ROOT}"  ["metrics-addr"]="${DEFAULT_PROMETHEUS_LISTEN}" ["experimental"]="${DEFAULT_EXPERIMENTAL}" )
function usage {
    cat <<- EOF
Usage: $PROGNAME [ -h ]

Optional arguments:
    -h: Help
    -d: Change default docker data directory (default, ${DEFAULT_DATA_ROOT})
    -e: Disable experimental feature (default, enabled)
    -s: Disable docker service (default, enabled)
    -p: Change prometheus bind URL (default, ${DEFAULT_PROMETHEUS_LISTEN})
    -v: Enable debug mode

General usage example:

  $ $PROGNAME -v 
  $ $PROGNAME -d /data/docker-data
  $ $PROGNAME -e true
  $ $PROGNAME -p "0.0.0.0:9323"
  $ $PROGNAME -s

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
    while getopts vd:sp:eh OPTION
    do
        case $OPTION in
            h) usage;;
            d) OPTIONS["data_root"]=$OPTARG;;
            e) OPTIONS["experimental"]="false";;
            s) disable_service=true;;
            p) OPTIONS["metrics-addr"]=$OPTARG;;
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
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
       $(lsb_release -cs) stable"
    apt-get update
    apt-get install docker-ce
    

  elif [ $pkg_mgr = "yum" ];then
    yum remove docker docker-client docker-client-latest docker-common \
         docker-latest docker-latest-logrotate docker-logrotate docker-selinux \
         docker-engine-selinux docker-engine -y
    yum install -y yum-utils device-mapper-persistent-data lvm2
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    yum install -y docker-ce

  fi
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

function set_daemon_option() {
    echo "{" > $DAEMON_JSON_FILE
    echo -e "  \"data-root\": \"${OPTIONS[data_root]}\","       >> $DAEMON_JSON_FILE
    echo -e "  \"metrics-addr\": \"${OPTIONS[metrics-addr]}\"," >> $DAEMON_JSON_FILE
    echo -e "  \"experimental\": ${OPTIONS[experimental]}"      >> $DAEMON_JSON_FILE
    echo "}" >> $DAEMON_JSON_FILE
}

function main {

    #[ ${#@} -eq 0 ] && { usage; exit 1; }

    parse_arguments "$@"
    
    [ `id -u` -ne 0 ] && { echo "The script must be run as root! (you can use sudo)"; exit 1; }

    pkg_mgr=$(get_pkg_manager)
   
    install_docker $pkg_mgr
    [ $no_docker_compose ] || install_docker_compose

    echo
    echo "Add $USER into the docker group..."
    usermod -aG docker $USER

    set_daemon_option

    systemctl start docker
    [ $disable_service ] || systemctl enable docker
}

main "$@"

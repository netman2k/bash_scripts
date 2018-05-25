#!/bin/bash
#
# Name: install_docker.sh
#
# Description:
#   Installing Docker and composer
declare -r PROGNAME=$(basename $0)
declare -r PROGDIR=$(readlink -m $(dirname $0))

function usage {
    cat <<- EOF
Usage: $PROGNAME [ -h ]

Optional arguments:
    -h: Help
    -d: Change default docker data directory
    -s: Disables docker service
    -v: Enable debug mode

General usage example:

  $ $PROGNAME -v 
  $ $PROGNAME -d /data/docker-data

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
    while getopts vd:sh OPTION
    do
        case $OPTION in
            h) usage;;
            d) docker_data_directory=$2; shift;;
            v) set -x;;
            s) disable_docker_service=true;;
        esac
    done
}

function install_docker(){
  local pkg_mgr=${1}

  echo
  echo "Installing Docker..."
  echo

  if [[ $pkg_mgr =~ (apt[-get]?) ]];then
    sudo apt-get remove docker docker-engine docker.io
    sudo apt-get update
    sudo apt-get install apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
       $(lsb_release -cs) stable"
    sudo apt-get update
    sudo apt-get install docker-ce
    

  elif [ $pkg_mgr = "yum" ];then
    sudo yum remove docker docker-client docker-client-latest docker-common \
         docker-latest docker-latest-logrotate docker-logrotate docker-selinux \
         docker-engine-selinux docker-engine -y
    sudo yum install -y yum-utils device-mapper-persistent-data lvm2
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y docker-ce

  fi
}


function install_docker_compose(){
  echo
  echo "Installing Docker compose..."
  echo

  sudo curl -L https://github.com/docker/compose/releases/download/1.19.0/docker-compose-`uname -s`-`uname -m` \
  -o /usr/local/bin/docker-compose
  sudo curl -L https://raw.githubusercontent.com/docker/compose/1.19.0/contrib/completion/bash/docker-compose \
  -o /etc/bash_completion.d/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
}

function main {

    #[ ${#@} -eq 0 ] && { usage; exit 1; }

    parse_arguments "$@"
    
    pkg_mgr=$(get_pkg_manager)
   
    install_docker $pkg_mgr
    [ $no_docker_compose ] || install_docker_compose

    echo
    echo "Add $USER into the docker group..."
    sudo usermod -aG docker $USER

    # Change the default data location
    if [ -n $docker_data_directory ];then 
      echo -e "{\n\t\"data-root\": \"${docker_data_directory}\"\n}" > /etc/docker/daemon.json
    fi

    sudo service docker start
    [ $disable_docker_service ] || sudo service enable docker
}

main "$@"

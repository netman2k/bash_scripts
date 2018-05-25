#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PUPPET_MODULE_PATH="/tmp/modules-$$"

if [ -f ${DIR}/functions ];then
  source ${DIR}/functions
else
  echo "This script requires functions script"
  exit 1
fi


function usage(){
  echo "Usage: `basename $0` [parameters]"
  echo
  echo "Parameters:"
  echo -e "\t--server: Use this option to set puppet server in /etc/puppetlabs/puppet/puppet.conf"
  echo -e "\t--ca-server: Use this option to set puppet ca_server in /etc/puppetlabs/puppet/puppet.conf"
  echo -e "\t--disable: Use this option to disable puppet service"
  echo -e "\t--stopped: Use this option not to start puppet service"
  exit 2

}

function set_puppetserver(){
  [ -z $1 ] && return 0

  puppet resource ini_setting server ensure=present \
   path=/etc/puppetlabs/puppet/puppet.conf \
   section=main \
   setting=server \
   value="$1" \
   --modulepath=$PUPPET_MODULE_PATH 

}

function set_ca_server(){
  [ -z $1 ] && return 0

  puppet resource ini_setting ca_server ensure=present \
   path=/etc/puppetlabs/puppet/puppet.conf \
   section=main \
   setting=ca_server \
   value="$1" \
   --modulepath=$PUPPET_MODULE_PATH 

}


function main(){
  # parse getopts options
  local tmp_getopts=`getopt -o h --long help,server:,ca-server:,disable,stopped -- "$@"`
  [ $? != 0 ] && usage
  eval set -- "$tmp_getopts"

  while true; do
      case "$1" in
          -h|--help)          usage;;
          --server)           local server=$2;        shift 2;;
          --ca-server)        local ca_server=$2;     shift 2;;
          --disable)          local disable="true";   shift;;
          --stopped)          local stopped="true";   shift;;
          --) shift; break;;
          *) usage;;
      esac
  done


  install_puppet agent

  if [ ! "${server}" = "" ] || [ ! "${ca_server}" = "" ];then
    puppet module install puppetlabs/inifile --modulepath=$PUPPET_MODULE_PATH
    [ ! "${server}" = "" ]      || set_puppetserver $server
    [ ! "${ca_server}" = "" ]   || set_ca_server $ca_server
  fi

  if [ ! "${disable}" = "true" ];then
    sudo systemctl enable puppet.service
  elif [ ! "${stopped}" = "true" ];then
    sudo systemctl enable puppet.service
  else
    sudo systemctl disable puppet.service
    sudo systemctl stop puppet.service
  fi

}

main "$@"

#!/bin/bash
#
# Initializing PuppetServer via theforeman-puppet module
#
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

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
  echo -e "\t-a --alt_dns_names: Use this option to set alt_dns_names you typed on the puppet.conf file"
  echo -e "\t\t IMPORTANT: You need to surrounding the value with single or double quote and each value"
  echo -e "\t\t            should be separated with comma(,)"
  echo -e "\t\t\           example) 'puppet.example.com', 'puppetserver.example.com'"
  echo -e "\t-d --set-dummy-hosts: Use this option to add alt_dns_names into the /etc/hosts file"
  exit 2
}

function init_puppet(){

  puppet module install theforeman-puppet --version 6.0.1

  cat <<EOF > /tmp/install.pp
  class { '::puppet':
    server                => true,
    # Without Foreman
    server_foreman        => false,
    server_reports        => 'store',
    server_external_nodes => '',
    # for R10K
    server_environments   => [],
EOF

  [ "${1}" = "" ] || echo "    dns_alt_names => [ ${1} ]," >> /tmp/install.pp
  echo "  }" >> /tmp/install.pp

  puppet apply /tmp/install.pp --test

}

function main(){

  # parse getopts options
  local tmp_getopts=`getopt -o hda: --long help,set-dummy-hosts,alt_dns_names: -- "$@"`
  [ $? != 0 ] && usage
  eval set -- "$tmp_getopts"

  while true; do
      case "$1" in
          -h|--help)              usage;;
          -a|--alt_dns_names)     local alt_dns_names=$2;               shift 2;;
          -d|--set-dummy-hosts)   local set_dummy_hosts="true";         shift;;
          --) shift; break;;
          *) usage;;
      esac
  done

  install_puppet
  init_puppet $alt_dns_names

  source /etc/profile.d/puppet-agent.sh
}

main "$@"

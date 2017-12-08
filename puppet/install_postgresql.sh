#!/bin/bash
# description: this script deploys PostgreSQL server on this server.
#              via using puppet
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
  echo -e "\t--user-account: A username to create"
  echo -e "\t--user-password: A password of the user"
  echo -e "\t-d or --database: A database to create"
  echo -e "\t-p or --password: A password of the postgres account"
  echo -e "\t--no-contrib: not to install contrib package"
  echo
  echo -e "Example)"
  echo -e "  $DIR/$(basename $0) --version=9.6 --password 'please_change_me' -d 'puppetdb' --user-account 'puppetdb' --user-password 'please_change_me'"
  exit 2
}



function main(){

  # parse getopts options
  local tmp_getopts=`getopt -o hp:d: --long help,user-account:,user-password:,password:,database:,version:,no-contrib -- "$@"`
  [ $? != 0 ] && usage
  eval set -- "$tmp_getopts"

  while true; do
      case "$1" in
          -h|--help)              usage;;
          --user-account)         local a_user=$2;              shift 2;;
          --user-password)        local a_user_password=$2;     shift 2;;
          -p|--password)          local pg_password=$2;         shift 2;;
          -d|--database)          local database=$2;            shift 2;;
          --no-contrib)           local no_contrib="true";      shift ;;
          --version)              local pg_version="${2}";      shift 2;;
          --) shift; break;;
          *) usage;;
      esac
  done

  rpm -qi puppet-agent > /dev/null || install_puppet agent


  # Clean up all modules previously used
  rm -rf $PUPPET_MODULE_PATH/*

  puppet module install puppetlabs-stdlib --version "4.21.0" --modulepath=$PUPPET_MODULE_PATH
    puppet module install puppetlabs-concat --version "4.1.0" --modulepath=$PUPPET_MODULE_PATH
      puppet module install puppetlabs-postgresql --version "5.2.0" --modulepath=$PUPPET_MODULE_PATH

  if [ -z $pg_password ];then
    echo "You need to set the pg_password option"
    exit 1
  fi

  TMP_FILE=/tmp/postgresql_$$.pp

  # If you specify the version of the postgresql set the global variable
  if [ ! -z "${pg_version}" ];then
    cat <<EOF > $TMP_FILE
class { 'postgresql::globals':
  manage_package_repo => true,
  version             => '${pg_version}',
}->
EOF
  fi

  cat <<EOF >> $TMP_FILE
class { 'postgresql::server':
  ip_mask_deny_postgres_user => '0.0.0.0/32',
  ip_mask_allow_all_users    => '0.0.0.0/0',
  listen_addresses           => '*',
  postgres_password          => '${pg_password}',
}
EOF


  if [ -z "${no_contrib}" ];then
  cat <<EOF >> $TMP_FILE
class { 'postgresql::server::contrib': }
EOF
  fi

  if [[ ! -z ${database} && ! -z ${a_user} && ! -z ${a_user_password} ]] ;then
cat <<EOF >> $TMP_FILE
postgresql::server::db { '${database}':
  user     => '${a_user}',
  password => postgresql_password('${a_user}', '${a_user_password}'),
}
EOF
  fi

  puppet apply $TMP_FILE --modulepath=$PUPPET_MODULE_PATH

  rm -f $TMP_FILE

}

main "$@"

#!/bin/bash
# description: this script deploys PostgreSQL server on this server.
#              via using puppet
# TODO
# - Set readonly database
#   >= puppetdb 1.6 can set read only database
#
declare -r DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
declare -r PUPPET_MODULE_PATH="/tmp/modules-$$"
declare -r MEM_TOTAL_IN_KB=$(grep "MemTotal" /proc/meminfo  | awk '{print $2}')
declare -r DEFAULT_JVM_HEAP_SIZE="$(( $MEM_TOTAL_IN_KB * 60 / 100 / 1024 ))"
declare -r DEFAULT_JVM_EXTRA_ARGS="+AlwaysPreTouch"

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
  echo -e "\t--pg-host: A host to use for DB connection"
  echo -e "\t--pg-port: A host port to use for DB connection"
  echo -e "\t--pg-database: A database name to use for DB connection"
  echo -e "\t--pg-account: A username to use for DB connection"
  echo -e "\t--pg-password: A password to use for DB connection"
  echo -e "\t--preserve-pp: choose whether temporary pp file should be remained or not"
  echo -e "\t--enable:: Enable PuppetDB service, default false"
  echo
  echo
  echo "Example:"
  echo "`basename $0` --pg-host 172.16.0.24 --pg-database puppetdb --pg-account puppetdb"
  echo
  exit 2
}



function main(){

  # parse getopts options
  local tmp_getopts=`getopt -o h --long help,pg-account:,pg-password:,pg-host:,pg-database:,pg-port:,version:,preserve-pp:,enable -- "$@"`
  [ $? != 0 ] && usage
  eval set -- "$tmp_getopts"

  local pg_host="localhost"
  local pg_port="5432"
  local pg_database="puppetdb"
  local pg_account="puppetdb"
  local preserve_pp="false"
  local start_service="stopped"

  while true; do
      case "$1" in
          -h|--help)              usage;;
          --pg-host)              pg_host=$2;             shift 2;;
          --pg-port)              pg_port=$2;             shift 2;;
          --pg-database)          pg_database=$2;         shift 2;;
          --pg-account)           pg_account=$2;          shift 2;;
          --pg-password)          pg_password=$2;         shift 2;;
          --preserve-pp)          preserve_pp=$2;         shift 2;;
          --enable)               start_service="running";           shift;;
          --) shift; break;;
          *) usage;;
      esac
  done


  rpm -qi puppet-agent > /dev/null || install_puppet agent

  puppet module install puppetlabs/puppetdb --version "5.1.2" --modulepath=$PUPPET_MODULE_PATH

  echo
  echo "===================================================="
  echo "Your hostname : $(hostname -f)"
  echo "===================================================="
  echo
  echo "Is it correct? Do you want me to continue? (Y/N)"

  read answer

  [ "${answer}" = "Y" -o "${answer}" = "y" ] || { echo "Exit"; exit 1;  }

  if [ -z $pg_password ];then
    echo
    echo "Please enter password of the ${pg_database}:"
    read pg_password
  fi

  echo
  echo "Continue to install PuppetDB..."
  echo
  TMP_FILE=/tmp/puppetdb_$$.pp

  cat <<'EOF' > $TMP_FILE
class { 'puppetdb::server':
  listen_address    => '0.0.0.0',
  ssl_set_cert_paths=> true,
  ssl_cert_path     => "/etc/puppetlabs/puppet/ssl/certs/${::fqdn}.pem",
  ssl_ca_cert_path  => "/etc/puppetlabs/puppet/ssl/certs/ca.pem",
  ssl_key_path      => "/etc/puppetlabs/puppet/ssl/private_keys/${::fqdn}.pem",
  manage_firewall   => false,
EOF

  cat <<EOF >> $TMP_FILE
  java_args         => { 
    '-Xmx' => "${DEFAULT_JVM_HEAP_SIZE}m",
    '-Xms' => "${DEFAULT_JVM_HEAP_SIZE}m",
    '-XX:' => "${DEFAULT_JVM_EXTRA_ARGS}",
  },
  puppetdb_service_status => '${start_service}',
  database_host     => '${pg_host}',
  database_port     => '${pg_port}',
  database_name     => '${pg_database}', 
  database_username => '${pg_account}',
  database_password => '${pg_password}',
  node_ttl          => '7d',
  node_purge_ttl    => '14d',
}
EOF

  puppet apply $TMP_FILE --modulepath=$PUPPET_MODULE_PATH

  # If the puppet account does not exist, create it first
  getent passwd puppet || useradd -r puppet
  usermod -g puppetdb -G puppet puppetdb 

  [ "${preserve_pp}" = "false" ] && rm -f $TMP_FILE

  echo
  echo "======================================================================="
  echo "[ NOTICE ]"
  echo
  echo "You need a SSL certificate to run PuppetDB"
  echo 
  echo "follow this orders:"
  echo
  echo "1. Request a certificate from the Puppet CA" 
  echo "  puppet certificate generate --ca-location remote \\"
  echo "    --ca_server puppet2.example.net \\"
  echo "    --dns-alt-names puppetdb.example.net $(hostname -f)"
  echo
  echo "2. After requesting, you should sign the CSR on the Puppet CA"
  echo "  puppet cert sign $(hostname -f) --allow-dns-alt-names"
  echo 
  echo "2. Run puppet agent"
  echo "   source /etc/profile.d/puppet-agent.sh"
  echo "   puppet agent -t"
  echo
  echo "3. Enable & Start puppetdb service"
  echo "   for x in enable start;do systemctl \$x puppetdb.service; done"
  echo
  echo "======================================================================="
  echo
}

main "$@"

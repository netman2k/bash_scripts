#!/bin/bash
#
# Initializing PuppetServer via theforeman-puppet module
#
#
declare -r DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
declare -r MODULE_PATH="/tmp/modules_$$"
declare -r INSTALL_PP="/tmp/puppet_install.pp"
declare -r MEM_TOTAL_IN_KB=$(grep "MemTotal" /proc/meminfo  | awk '{print $2}')
declare -r DEFAULT_FOREMAN_FQDN="foreman.cdngp.net"
declare -r DEFAULT_PUPPETDB_FQDN="puppetdb.cdngp.net"
declare -r DEFAULT_PUPPETCA_FQDN="puppetca.cdngp.net"
declare -r DEFAULT_JVM_HEAP_SIZE="$(( $MEM_TOTAL_IN_KB * 60 / 100 / 1024 ))"
declare -r DEFAULT_JVM_EXTRA_ARGS="-XX:+AlwaysPreTouch"
declare -r DEFAULT_GIT_REPO_PATH="/var/lib/gitolite/repositories/puppet.git"
declare -r HOSTNAME=$(hostname -f)


if [ -f ${DIR}/functions ];then
  source ${DIR}/functions
else
  echo "This script requires functions script"
  exit 1
fi


# Convert entered input DNS alternative names to a puppet syntax array string
function _to_puppet_array(){
  local alt_dns_names=$1
  local names='['
  IFS=','; for name in ${alt_dns_names[@]};do names="${names}'$name',";done
  names="${names} ],"
  unset IFS
  echo $names
}

# Disable CA
function disable_ca(){
  echo "    server_ca                   => false,"            >> $INSTALL_PP 
}

# Set Git repo 
function set_git_repo(){
  local -r git_repo_path=${1:-$DEFAULT_GIT_REPO_PATH}

  puppet module install --modulepath=$MODULE_PATH theforeman-git --version 2.0.0

  echo "    server_git_repo             => true,"                 >> $INSTALL_PP
  if [ "x${git_repo_path}" != "x" ];then
    echo "    server_git_repo_path        => '${git_repo_path}'," >> $INSTALL_PP
  fi
   
}

# Set DNS alternative names
function set_alt_dns_names(){
  local -r alt_dns_names=$(_to_puppet_array $1)
  echo "    dns_alt_names               => ${alt_dns_names}" >> $INSTALL_PP
}

# Set Foreman related settings
function set_foreman(){
  local foreman_fqdn=$1

  if [ "x${foreman_fqdn}" = "x" ];then 
    echo "    server_foreman              => false,"              >> $INSTALL_PP
    echo "    server_external_nodes       => '',"                 >> $INSTALL_PP
  else
    echo "    server_foreman_url          => '${foreman_fqdn}',"  >> $INSTALL_PP
  fi
}

# Set PuppetDB related settings
function set_puppetdb(){
  local -r puppetdb_fqdn=$1

  if [ "x${puppetdb_fqdn}" != "x" ];then
    puppet module install --modulepath=$MODULE_PATH puppetlabs-puppetdb --version 5.1.2

    echo "    server_puppetdb_host        => '${puppetdb_fqdn}',"   >> $INSTALL_PP
    echo "    server_storeconfigs_backend => 'puppetdb',"           >> $INSTALL_PP
  fi
}

function set_reports(){
  local foreman_fqdn=$1
  local puppetdb_fqdn=$2

  local reports="store"
  [ "x${foreman_fqdn}"  = "x" ] || reports="${reports},foreman"
  [ "x${puppetdb_fqdn}" = "x" ] || reports="${reports},puppetdb"

  echo "    server_reports              => '${reports}'," >> $INSTALL_PP
}

# Set JVM related settings
# - server_jvm_extra_args : -XX:+AlwaysPreTouch
# - server_jvm_max_heap_size
# - server_jvm_min_heap_size
function set_jvm(){
  local jvm_heap_size=${1:-$DEFAULT_JVM_HEAP_SIZE}
  local jvm_extra_args=${2:-$DEFAULT_JVM_EXTRA_ARGS}

  echo "    server_jvm_max_heap_size    => '${jvm_heap_size}m',"    >> $INSTALL_PP
  echo "    server_jvm_min_heap_size    => '${jvm_heap_size}m',"    >> $INSTALL_PP
  echo "    server_jvm_extra_args       => '${jvm_extra_args}',"    >> $INSTALL_PP
}

function set_extras(){
  # Prevent from creating directories which are will be used for dynamic env.
  echo "    server_dynamic_environments => true,"    >> $INSTALL_PP

  # Prevent from regenerate certificate when you roll back to real name
  # for example, we use a name puppet2-ca.cdngp.net for Puppet CA 
  # but the real name of the server will be h0-s1028.p61-icn.cdngp.net
  # Due to these setting, we can use common name for serving puppet agent
  # and hostname can be used by using fqdn facter as well.
  echo "    server_certname             => '${HOSTNAME}',"    >> $INSTALL_PP
  echo "    client_certname             => '${HOSTNAME}',"    >> $INSTALL_PP

  # Set autosign entries
  echo "    autosign_entries            => [ '*.cdngp.net' ]," >> $INSTALL_PP
}

# Opening a PP file
function _begin(){
  cat <<EOF > $INSTALL_PP
  class { '::puppet':
    server                      => true,
    server_environments         => [], # for R10K
EOF
}

# Closing a PP file
function _end(){
  echo "  }" >> $INSTALL_PP
}

function usage(){
  echo "Usage: `basename $0` [parameters]"
  echo
  echo "Parameters:"
  echo -e "\t--alt-dns-names     Use this option to set alt_dns_names you typed on the puppet.conf file"
  echo -e "\t                    IMPORTANT: each DNS values should be separated by comma(,) with no spaces"
  echo -e "\t                    i.e.) puppet.example.com,puppetserver.example.com"
  echo
  echo -e "\t--no-ca             Use this option not to enable CA on this server"
  echo
  echo -e "\t--git-repo          Use this option to set a Git repository on this server"
  echo -e "\t                    With this option, puppet environment will be set as you commit any codes in the repository"
  echo 
  echo -e "\t--foreman-fqdn      Use this option to set an URL of Foreman. If it is not set, this script will not integrate with Foreman"
  echo -e "\t                    If it is not specified, this script will not integrate with Foreman"
  echo
  echo -e "\t--puppetdb-fqdn     Use this option to set an URL of PuppetDB"
  echo -e "\t                    Warning: PuppetDB should be signed by the same CA"
  echo -e "\t                    otherwise, it will not work properly"
  echo
  echo -e "\t--jvm-heap          Use this option to set JVM extra options"
  echo -e "\t                    Default, ${DEFAULT_JVM_HEAP_SIZE}m"
  echo -e "\t--jvm-extra         Use this option to set JVM extra options"
  echo -e "\t                    Default, ${DEFAULT_JVM_EXTRA_ARGS}"
  echo 
  echo -e "\t--no-run            Use this option to generate a pp file, ${INSTALL_PP} to see without run puppet"
  echo 
  echo "Examples:"
  echo -e "\t${0} --foreman-fqdn=foreman.example.com"
  echo -e "\t${0} --puppetdb-fqdn=puppetdb.example.com"
  echo -e "\t${0} --no-ca --ca-fqdn=puppetca.example.com"
  echo -e "\t${0} --alt-dns-names=puppet.example.com,puppet-lb.example.com"
  echo -e "\t${0} --git-repo --git-path=/var/lib/gitolite/repositories/puppet.git"
  echo -e "\t${0} --no-run"
  echo
  echo "CA server:"
  echo -e "\t${0} --alt-dns-names=puppet2.cdngp.net,puppet2-global.cdngp.net,puppet2-ca.cdngp.net,puppet"
  echo -e "\t     WARNING: before run this command, you should set your hostname with this FQDN puppet2-ca.cdngp.net"
  echo -e "\t              and after done installing, you can set your real hostname ie. h0-s1028.p61-icn.cdngp.net"
  echo
  echo "PuppetServer:"
  echo -e "\t${0} --no-ca --alt-dns-names=puppet2.cdngp.net,puppet2-global.cdngp.net,puppet"
  echo
  echo
  exit 2
}


function main(){ 

  # parse getopts options
  local tmp_getopts=`getopt -o h,n --long help,alt-dns-names:,no-ca,git-repo,git-path:,foreman-fqdn:,puppetdb-fqdn:,ca-fqdn:,jvm-extra:,jvm-heap:,no-run -- "$@"`
  [ $? != 0 ] && usage
  eval set -- "$tmp_getopts"

  while true; do
      case "$1" in
          -h|--help)                    usage;;
          --alt-dns-names)              local alt_dns_names=$2;                     shift 2;;
          --foreman-fqdn)               local foreman_fqdn=$2;                      shift 2;;
          --puppetdb-fqdn)              local puppetdb_fqdn=$2;                     shift 2;;
          --no-ca)                      local no_puppet_ca="false";                 shift;;
          --ca-fqdn)                    local ca_fqdn=$2;                           shift 2;;
          --git-repo)                   local git_repo="true";                	    shift;;
          --git-path)                   local git_repo_path=$2;                     shift 2;;
          --jvm-heap)                   local jvm_heap=$2;                          shift 2;;
          --jvm-extra)                  local jvm_extras=$2;                        shift 2;;
          -n|--no-run)                  local no_run="true";                        shift;;
          --) shift; break;;
          *) usage;;
      esac
  done

  echo
  echo "===================================================="
  echo "Your hostname : $(hostname -f)"
  echo "===================================================="
  echo
  echo "Is it correct? Do you want me to continue? (Y/N)"

  read answer

  [ "${answer}" = "Y" -o "${answer}" = "y" ] || { echo "Exit"; exit 1;  }

  install_puppet
  [ $? -eq 1 ] && { echo "Error occurred" 2>&1 ; exit 1; }

  source /etc/profile.d/puppet-agent.sh

  puppet module install --modulepath=$MODULE_PATH theforeman-puppet --version 6.0.1

  _begin
  set_foreman $foreman_fqdn
  set_jvm $jvm_heap $jvm_extras
  set_puppetdb $puppetdb_fqdn 
  set_reports $foreman_fqdn $puppetdb_fqdn
  set_extras
  

  [ "x${no_puppet_ca}" = "x"  ] || disable_ca
  [ "${git_repo}" != "true"   ] || set_git_repo $git_repo_path
  [ "x${alt_dns_names}" = "x" ] || set_alt_dns_names $alt_dns_names
  _end

  if [ "x${no_run}" = "x" ];then
    puppet apply $INSTALL_PP --test --modulepath $MODULE_PATH
    
    /opt/puppetlabs/bin/puppetserver gem install hiera-eyaml
    /opt/puppetlabs/puppet/bin/gem install hiera-eyaml

  else
    echo
    echo "- [ Generated PP file ] ----------------------------------------"
    cat $INSTALL_PP
    echo "----------------------------------------------------------------"
  fi

}

main "$@"

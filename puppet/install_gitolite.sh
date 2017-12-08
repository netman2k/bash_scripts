#!/bin/bash
declare -r PROGNAME=$(basename $0)
declare -r PROGDIR=$(readlink -m $(dirname $0))
declare -r ARGS="$@"

declare GITOLITE_ADMIN="gitolite-admin"
declare GITOLITE_USER="git"
declare GITOLITE_GROUP="git"
declare PUPPET_BIN="/opt/puppetlabs/puppet/bin/puppet"
declare PUPPET_MODULE_PATH="/opt/puppetlabs/puppet/modules"

function gen_and_run(){

  local pub_key=${1}
  local pub_key_content="$(cat $pub_key)"
  echo
  echo "# Installing required puppet module - echoes/gitolite..."
  $PUPPET_BIN module install --modulepath=$PUPPET_MODULE_PATH 'echoes-gitolite'

  echo
  echo "# Generating and running installation puppet class..."
  cat <<-EOF > /tmp/gitolite.pp
class { '::gitolite':
  user_name         => '${GITOLITE_USER}',
  group_name        => '${GITOLITE_GROUP}',
  admin_key_content => '${pub_key_content}',
}
EOF

  $PUPPET_BIN apply --modulepath=$PUPPET_MODULE_PATH /tmp/gitolite.pp

}

function usage {
    cat <<- EOF
Usage: $PROGNAME -p public_key [ -a gitolite_admin -u gitolite_user -g gitolite_group ]

Optional arguments to override default values:
    -a: Account name of the gitolite administrator (default: ${GITOLITE_ADMIN})
    -u: Account name of the gitolite (default: ${GITOLITE_USER})
    -g: Group name of the gitolite (default: ${GITOLITE_GROUP})
    -p: SSH public Key file that will be used to init gitolite.
        Note that, this option this script makes not to create an administrator account, 
        gitolite-admin on this server. 
        If you are willing to manage the gitolite-admin repository remotely, 
        please set this option

Example:
  $PROGRAM
  $PROGRAM -u ${GITOLITE_USER} -g ${GITOLITE_GROUP}
  $PROGRAM -p "/tmp/gitolite_sshkey.pub"

EOF

    exit 0
}

function add_admin_user(){
  # Check existance
  id $GITOLITE_ADMIN &> /dev/null
  [ $? -eq 0 ] && { echo "${GITOLITE_ADMIN} is already exist" 1>&2 ; return; }

  echo
  echo "# Creating the gitolite administrator account..."

  useradd -r -m -k /etc/skel -p '!!' $GITOLITE_ADMIN
  sudo -u $GITOLITE_ADMIN mkdir /home/$GITOLITE_ADMIN/.ssh

  ssh-keygen \
    -t rsa -b 4096 \
    -C "ssh key for gitolite admin $(date +%F)" \
    -f /home/$GITOLITE_ADMIN/.ssh/id_rsa \
    -N ''
}


function parse_arguments {
  while getopts a:r:u:g:p:h OPTION
  do
    case $OPTION in
      a) GITOLITE_ADMIN=$OPTARG;;
      u) GITOLITE_USER=$OPTARG;;
      g) GITOLITE_GROUP=$OPTARG;;
      p) PUBKEY=$OPTARG;;
      h) usage;;
    esac
  done
}

function main {

    parse_arguments $ARGS

    which puppet > /dev/null 2>&1
    [ $? -eq 1 ] && { echo "Puppet agent is require to run this script" 1>&2; exit 1; }

    rpm -qi epel-release &> /dev/null || yum install -y epel-release

    if [ "x${PUBKEY}" = "x" ];then
      add_admin_user
      PUBKEY=/home/$GITOLITE_ADMIN/.ssh/id_rsa.pub
    fi

    gen_and_run $PUBKEY
 
}

main


#!/bin/bash
#
# Generating a GPG key
#
# Please look up the reference page:
# https://www.gnupg.org/documentation/manuals/gnupg/Unattended-GPG-key-generation.html
#
declare -r PROGNAME=$(basename $0)
declare -r PROGDIR=$(readlink -m $(dirname $0))

declare -r DEFAULT_GPG_HOME_DIR="$(mktemp -d)"
declare -r DEFAULT_ANSWER_FILE="${DEFAULT_GPG_HOME_DIR}/unattend_answer"
declare -r DEFAULT_EXPORT_FILE="${DEFAULT_GPG_HOME_DIR}/GPG-KEY-$(date +%F)"
declare -r DEFAULT_GPG_NAME="GPG Key"
declare -r DEFAULT_GPG_COMMENT="My GPG key for signing something"
declare -r DEFAULT_GPG_EMAIL="your@email"
declare -r DEFAULT_EXPIRE_DATE="$(($(date +%Y) + 10))-$(date +%m-%d)"
declare -r DEFAULT_PASSPHRASE="$(date "+%F %H:%M:%S" | sha256sum | base64 | head -c 16)"


# Check RNGD option
function check_rngd(){
    if [[ $EUID -ne 0 ]]; then
        echo
        echo "----[ NOTE ]-----------------------------------------------------------"
        echo "  If you get feel this script is runing too long," 
        echo "  you might change the setting of the rngd daemon as below:"
        echo
        echo '  Set the EXTRAOPTIONS with these="-r /dev/urandom -o /dev/random -t 5"'
        echo "-----------------------------------------------------------------------"
        echo
    else
        if [ $(grep -c 'EXTRAOPTIONS=""' /etc/sysconfig/rngd) -eq 1 ] ;then
            echo "# Modifying the rngd daemon option..."
            sed -i 's|^\(EXTRAOPTIONS=\).*$|\1"-r /dev/urandom -o /dev/random -t 5"|' /etc/sysconfig/rngd
        fi
    fi    
}


# Initialize GPG Directory
function init_gpg_home_dir(){
    local gpg_home=${1:-$DEFAULT_GPG_HOME_DIR}
    if [ ! -d $gpg_home ];then    
        echo
        echo "# Create GNUPG directory."
        mkdir $gpg_home
        chmod 700 $gpg_home
    fi
}


function gen_gpg(){
    local gpg_name=${1:-$DEFAULT_GPG_NAME}
    local gpg_comment=${2:-$DEFAULT_GPG_COMMENT}
    local gpg_email=${3:-$DEFAULT_GPG_EMAIL}
    local gpg_expire_date=${4:-$DEFAULT_EXPIRE_DATE}
    local gpg_passphrase=${5:-$DEFAULT_PASSPHRASE}
    local gpg_home=${6:-$DEFAULT_GPG_HOME_DIR}
    local answer_file=${7:-$DEFAULT_ANSWER_FILE}
    local dry_run=$8

    echo
    echo "# Creating a answer file for unattended key generation."

    # Creating an answer file
    echo "%echo Generating a GPG Key for ${gpg_name}"   > $answer_file
    echo "Key-Type: RSA"                                >> $answer_file
    echo "Key-Length: 4096"                             >> $answer_file
    echo "Subkey-Type: ELG-E"                           >> $answer_file
    echo "Subkey-Length: 4096"                          >> $answer_file
    echo "Name-Real: ${gpg_name}"                       >> $answer_file
    echo "Name-Comment: ${gpg_comment}"                 >> $answer_file
    echo "Name-Email: ${gpg_email}"                     >> $answer_file
    echo "Expire-Date: ${gpg_expire_date}"              >> $answer_file
    echo "Passphrase: ${gpg_passphrase}"                >> $answer_file

    if [ "x${dry_run}" = "x" ];then
        echo "%commit"      >> $answer_file  
    else
        echo "%dry-run"     >> $answer_file
    fi

    echo "%echo done"       >> $answer_file

    echo
    echo "# The content of the answer file."
    echo "-----------------------------------------------------------------------"
    cat $answer_file
    echo "-----------------------------------------------------------------------"

    echo
    echo "# Generate a GPG"
    gpg --batch --homedir $gpg_home --gen-key $answer_file

}

function check_gpg_key(){
    local gpg_home=${1:-$DEFAULT_GPG_HOME_DIR}
    echo
    echo "# Listing keys with GNUPGHOME env."
    GNUPGHOME=$gpg_home gpg --list-keys

    echo
    echo "# Listing keys without GNUPGHOME env."
    gpg --list-keys

}

function expert_public_key(){
    local gpg_home=${1:-$DEFAULT_GPG_HOME_DIR}
    local gpg_name=${2:-$DEFAULT_GPG_NAME}
    local gpg_export_file=${3:-$DEFAULT_EXPORT_FILE}
    
    echo 
    echo "# Export the public key from generated key ring to a text file."
    GNUPGHOME=$gpg_home gpg --export $gpg_name > $gpg_export_file
}

function usage {
    cat <<- EOF
Usage: $PROGNAME [ -n gpg_name -p passphrase -a answer_file -d gpg_home -e email -c comment -t expire_date -x export_file -D ]

Optional arguments:
    -a: Answer file to write (default: ${DEFAULT_ANSWER_FILE})
    -c: Comment (default: ${DEFAULT_GPG_COMMENT})
    -d: GPG home directory (default: ${DEFAULT_GPG_HOME_DIR})
    -m: Email address (default: ${DEFAULT_GPG_EMAIL})    
    -n: Name (default: ${DEFAULT_GPG_NAME})        
    -p: Passphrase (default: $DEFAULT_PASSPHRASE)
    -t: Expire date  (default: ${DEFAULT_EXPIRE_DATE})
    -x: Filename for exporting GPG public key
    -D: Set dry run mode in the answer file

General usage example:

  $ $PROGNAME -n '${DEFAULT_GPG_NAME}' -p ${DEFAULT_PASSPHRASE} -d ${HOME}/.gnupg \\
    -m '${DEFAULT_GPG_EMAIL}' -c '${DEFAULT_GPG_COMMENT}'

For singing RPM:
  $ $PROGNAME -n '${DEFAULT_GPG_NAME}' -p ${DEFAULT_PASSPHRASE} -d ${HOME}/.gnupg \\
    -m '${DEFAULT_GPG_EMAIL}' -c '${DEFAULT_GPG_COMMENT}' -x RPM-GPG-KEY-${DEFAULT_GPG_NAME}

EOF

    exit 0
}

function parse_arguments {
    while getopts a:c:d:m:n:p:t:x:Dh OPTION
    do
        case $OPTION in
            D) DRY_RUN="TRUE";;
            a) ANSWER_FILE=$OPTARG;;
            c) COMMENT=$OPTARG;;
            d) DIRECTORY=$OPTARG;;
            m) EMAIL=$OPTARG;;
            n) NAME=$OPTARG;;
            p) PASSPHRASE=$OPTARG;;
            t) EXPIRE_DATE=$OPTARG;;
            x) EXPORT_FILE=$OPTARG;;
            h) usage;;
        esac
    done
}

function main {

    [ ${#@} -eq 0 ] && { usage; exit 1; }

    parse_arguments "$@"
    
    check_rngd
    init_gpg_home_dir $DIRECTORY
    gen_gpg "${NAME}" "${COMMENT}" "${EMAIL}" "${EXPIRE_DATE}" "${PASSPHRASE}" "${DIRECTORY}" "${ANSWER_FILE}" "${DRY_RUN}" 
    if [ "x${DRY_RUN}" = "x" ];then
        check_gpg_key $DIRECTORY
        expert_public_key $DIRECTORY $NAME $EXPORT_FILE
    fi
}

main "$@"

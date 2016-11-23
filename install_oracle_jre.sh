#!/bin/bash
#DOWNLOAD_URL="http://download.oracle.com/otn-pub/java/jdk/8u112-b15/jdk-8u112-linux-x64.rpm"
DOWNLOAD_URL="http://download.oracle.com/otn-pub/java/jdk/8u112-b15/server-jre-8u112-linux-x64.tar.gz"
FILENAME=$(basename $DOWNLOAD_URL)
TMP_DIR="/tmp"
INSTALL_DIR="/usr/java"
PRESERVE_FILE="false"
CURL_DOWNLOAD_HEADER='Cookie: oraclelicense=accept-securebackup-cookie'

function do_install(){

	curl -v -j -k -L -H "${CURL_DOWNLOAD_HEADER}" $DOWNLOAD_URL > $TMP_DIR/$FILENAME
	[ "$?" -ne "0" ] && { echo "Download failed, exit" 1>&2; exit 1; }

	if [[ "${FILENAME}" == *"rpm" ]];then
		rpm -ihv $FILENAME

		[ "$?" -ne "0" ] && { echo "Install failed, exit" 1>&2; exit 1; }
	elif [[ "${FILENAME}" == *"tar.gz" ]];then

		[ ! -d $INSTALL_DIR ] && mkdir -vp $INSTALL_DIR

		tar -zxf $TMP_DIR/$FILENAME -C $INSTALL_DIR
		[ "$?" -ne "0" ] && { echo "Extract failed, exit" 1>&2; exit 1; }

	else
		echo "Install failed - Unknown file type" 1>&2
	fi

	echo "Install success"
	
}

function usage(){
	echo "Usage: $0 <Parameters>"
	echo
  echo "Parameters:"
  echo "  -u or --url: Change download url, Default: ${DOWNLOAD_URL}"
  echo "  -t or --temp-dir: Change temporary where stores downloaded file, Default: ${TMP_DIR}"
  echo "  -p or --preserve-file: Preserve downloaded file after installing, Default: ${PRESERVE_FILE}"
  echo "  -i or --install-dir: Change install directory, Default: ${INSTALL_DIR}"
  exit 0
}

function main(){

  # parse getopts options
  local tmp_getopts=`getopt -o hda: --long help,set-dummy-hosts,alt_dns_names: -- "$@"`
  [ $? != 0 ] && usage
  eval set -- "$tmp_getopts"

  while true; do
      case "$1" in
          -h|--help)            	usage;;
          -u|--url)     					DOWNLOAD_URL=$2;				shift 2;;
          -t|--temp-dir)     			TMP_DIR=$2;							shift 2;;
          -p|--preserve-file)     PRESERVE_FILE=$2;				shift 2;;
          -i|--install-dir)     	INSTALL_DIR=$2;				shift 2;;
          --) shift; break;;
          *) usage;;
      esac
  done

	do_install

}

main "$@"

#!/bin/bash
#DOWNLOAD_URL="http://download.oracle.com/otn-pub/java/jdk/8u112-b15/jdk-8u112-linux-x64.rpm"
DOWNLOAD_URL="http://download.oracle.com/otn-pub/java/jdk/8u112-b15/server-jre-8u112-linux-x64.tar.gz"
FILENAME=$(basename $DOWNLOAD_URL)
TMP_DIR="/tmp"
INSTALL_DIR="/usr/java"
PRESERVE_FILE="false"
PROFILE_FILE="/etc/profile.d/java.sh"
CURL_DOWNLOAD_OPTIONS='-v -j -k -L'
COOKIE='Cookie: oraclelicense=accept-securebackup-cookie'

function do_install(){

	curl $CURL_DOWNLOAD_OPTIONS -H "${COOKIE}" $DOWNLOAD_URL > $TMP_DIR/$FILENAME
	[ "$?" -ne "0" ] && { echo "Download failed, exit" 1>&2; exit 1; }

	if [[ "${FILENAME}" == *"rpm" ]];then
		rpm -ihv $FILENAME

		[ "$?" -ne "0" ] && { echo "Install failed, exit" 1>&2; exit 1; }
	elif [[ "${FILENAME}" == *"tar.gz" ]];then

		[ ! -d $INSTALL_DIR ] && mkdir -vp $INSTALL_DIR

		tar -zxf $TMP_DIR/$FILENAME -C $INSTALL_DIR
		[ "$?" -ne "0" ] && { echo "Extract failed, exit" 1>&2; exit 1; }


    echo "JAVA_HOME=${INSTALL_DIR}/jdk1.8.0_112" > $PROFILE_FILE
    echo "PATH=\${JAVA_HOME}/bin:\$PATH" >> $PROFILE_FILE

    source $PROFILE_FILE

    alternatives --install /usr/bin/java java $INSTALL_DIR/jdk1.8.0_112/bin/java 1
    alternatives --install /usr/bin/jar jar $INSTALL_DIR/jdk1.8.0_112/bin/jar 1
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

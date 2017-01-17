#!/bin/bash
#DOWNLOAD_URL="http://download.oracle.com/otn-pub/java/jdk/8u112-b15/jdk-8u112-linux-x64.rpm"
MINOR_VER="b15"
MAJOR_VER="8u112"
DOWNLOAD_URL="http://download.oracle.com/otn-pub/java/jdk/"
#DOWNLOAD_URL="http://download.oracle.com/otn-pub/java/jdk/${MAJOR_VER}-${MINOR_VER}/server-jre-8u112-linux-x64.tar.gz"
TMP_DIR="/tmp"
INSTALL_DIR="/usr/java"
JAVA_TYPE="server-jre"
PROFILE_FILE="/etc/profile.d/java.sh"
WGET_OPTIONS='--no-cookies --no-check-certificate -c'
COOKIE='Cookie: oraclelicense=accept-securebackup-cookie'

function do_install(){

  rpm -qi wget &> /dev/null || yum install wget -y

  _url="${DOWNLOAD_URL}${MAJOR_VER}-${MINOR_VER}/${JAVA_TYPE}-${MAJOR_VER}-linux-x64.tar.gz"
  _filename=$(basename $_url)
  _java_dir="${INSTALL_DIR}/oracle-java-${MAJOR_VER}"

  # Clean up previous file
  if [ -f $TMP_DIR/${_filename} ];then

    echo "[WARN] Found previous downloaded file: $TMP_DIR/${_filename}"
    echo
    echo "Do you want me to reuse it?"

    read answer
    if [ "${answer}" = "N" -o "${answer}" = "n" ];then
      rm -f $TMP_DIR/${_filename}
      wget $WGET_OPTIONS --header "${COOKIE}" $_url -O $TMP_DIR/$_filename
      [ "$?" -ne "0" ] && { echo "Download failed, exit" 1>&2; exit 1; }
    fi
  fi


  # Installing
  if [[ "${_filename}" == *"rpm" ]];then

    rpm -ihv $_filename
    [ "$?" -ne "0" ] && { echo "Install failed, exit" 1>&2; exit 1; }

  elif [[ "${_filename}" == *"tar.gz" ]];then

    [ ! -d $_java_dir ] && mkdir -vp $_java_dir

    tar -zxf $TMP_DIR/$_filename --strip 1 -C ${_java_dir}
    [ "$?" -ne "0" ] && { echo "Extract failed, exit" 1>&2; exit 1; }


    echo "JAVA_HOME=${_java_dir}" > $PROFILE_FILE
    echo "PATH=\${JAVA_HOME}/bin:\$PATH" >> $PROFILE_FILE

    source $PROFILE_FILE

    alternatives --install /usr/bin/java java ${_java_dir}/bin/java 1
    alternatives --set java ${_java_dir}/bin/java

    alternatives --install /usr/bin/jar jar ${_java_dir}/bin/jar 1
    alternatives --set jar ${_java_dir}/bin/jar

  else
    echo "Install failed - Unknown file type" 1>&2
  fi

  echo "Install success"

}

function usage(){
  echo "Usage: $0 <Parameters>"
  echo
  echo "Parameters:"
  echo "  -u or --download-url: Change download url, Default: ${DOWNLOAD_URL}"
  echo "  -m or --version-major: Major version of JAVA, Default: ${MAJOR_VER}"
  echo "  -n or --version-minor: Minor version of JAVA, Default: ${MINOR_VER}"
  echo "  -j or --java-type: Either server-jre, jre or jdk, Default: ${JAVA_TYPE}"
  echo "  -i or --install-dir: Change install directory, Default: ${INSTALL_DIR}"
  echo "  -t or --temp-dir: Change temporary where stores downloaded file, Default: ${TMP_DIR}"
  echo "  -o or --wget-options: Override wget options, Default: ${WGET_OPTIONS}"
  exit 0
}

function main(){

  # parse getopts options
  local tmp_getopts=`getopt -o hdu:m:n:t:i:p --long help,download-url:,version-major:,version-minor:,install-dir:,temp-dir:,preserve-file,java-type: -- "$@"`
  [ $? != 0 ] && usage
  eval set -- "$tmp_getopts"

  while true; do
      case "$1" in
          -h|--help)              usage;;
          -u|--download-url)      DOWNLOAD_URL=$2;        shift 2;;
          -m|--version-major)     MAJOR_VER=$2;           shift 2;;
          -n|--version-minor)     MINOR_VER=$2;           shift 2;;
          -t|--temp-dir)          TMP_DIR=$2;             shift 2;;
          -i|--install-dir)       INSTALL_DIR=$2;         shift 2;;
          -j|--java-type)         JAVA_TYPE="$2";         shift 2;;
          -o|--wget-options)      WGET_OPTIONS="$2";      shift 2;;
          --) shift; break;;
          *) usage;;
      esac
  done

  do_install

}

main "$@"


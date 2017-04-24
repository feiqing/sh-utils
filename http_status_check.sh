#!/bin/bash

APP_HOME=$(cd $(dirname ${BASH_SOURCE[0]})/..; pwd)
source "$APP_HOME/bin/setenv.sh"

CURL_BIN=/usr/bin/curl
SPACE_STR="..................................................................................................."
#TOMCAT_PORT="8080"
OUTIF=`/sbin/route -n | tail -1  | sed -e 's/.* \([^ ]*$\)/\1/'`
HTTP_IP="http://`/sbin/ifconfig | grep -A1 ${OUTIF} | grep inet | awk '{print $2}' | awk -F: '{print $2}'`:$TOMCAT_PORT"

#####################################
checkpage() {
  URL=$1
  TITLE=$2
  CHECK_TXT=$3
  echo "$CURL_BIN" "${HTTP_IP}${URL}"
  if [ "$TITLE" == "" ]; then
    TITLE=$URL
  fi
  len=`echo $TITLE | wc -c`
  len=`expr 60 - $len`
  echo -n -e "$TITLE ...${SPACE_STR:1:$len}"
  TMP_FILE=`$CURL_BIN -m 150 "${HTTP_IP}${URL}" 2>&1`
  if [ "$CHECK_TXT" != "" ]; then
    checkret=`echo "$TMP_FILE" | fgrep "$CHECK_TXT"`
    if [ "$checkret" == "" ]; then
        echo "[FAILED]"
        status=0
        error=1
    else
        echo "[OK]"
	    status_ok_http_url="http://`/sbin/ifconfig | grep -A1 ${OUTIF} | grep inet | awk '{print $2}' | awk -F: '{print $2}'`"
	    #####################################
	    status_code=`curl -o /dev/null -s -w %{http_code} $status_ok_http_url:8080/status.ok`
	    if [ "$status_code" == "200" ]; then
	         echo "check $status_ok_http_url:8080/status.ok [OK]"
	         status=2
	         error=0
	     else
	         echo "check $status_ok_http_url:8080/status.ok [FAILED]"
	         status=1
	         error=1
	     fi;
    fi;
  fi
  echo
  return $error
}
#####################################
#checkpage "/pub_check" "${APP_NAME}" "OK"
checkpage "/pub_check" "${APP_NAME}" "OK"

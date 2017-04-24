#!/bin/bash

PROG_NAME=$0
ACTION=$1
usage() {
    echo "Usage: $PROG_NAME {start|stop|online|offline|pubstart|restart}"
    exit 1;
}

if [ "$UID" -eq 0 ]; then
    echo "can't run as root, please use: sudo -u www $0 $@"
    exit 1
fi

if [ $# -lt 1 ]; then
    usage
fi

APP_HOME=$(cd $(dirname $0)/..; pwd)
source "$APP_HOME/bin/setenv.sh"

die() {
    if [ "$#" -gt 0 ]; then
        echo "ERROR:" "$@"
    fi
    exit 128
}


# 从tomcat 里拷来的
check_catalina_pid() {
  if [ ! -z "$CATALINA_PID" ]; then
    if [ -f "$CATALINA_PID" ]; then
      if [ -s "$CATALINA_PID" ]; then
        echo "Existing PID file found during start."
        if [ -r "$CATALINA_PID" ]; then
          PID=`cat "$CATALINA_PID"`
          ps -p $PID >/dev/null 2>&1
          if [ $? -eq 0 ] ; then
            echo "Tomcat appears to still be running with PID $PID. Start aborted."
            exit 1
          else
            echo "Removing/clearing stale PID file."
            rm -f "$CATALINA_PID" >/dev/null 2>&1
            if [ $? != 0 ]; then
              if [ -w "$CATALINA_PID" ]; then
                cat /dev/null > "$CATALINA_PID"
              else
                echo "Unable to remove or clear stale PID file. Start aborted."
                exit 1
              fi
            fi
          fi
        else
          echo "Unable to read PID file. Start aborted."
          exit 1
        fi
      else
        rm -f "$CATALINA_PID" >/dev/null 2>&1
        if [ $? != 0 ]; then
          if [ ! -w "$CATALINA_PID" ]; then
            echo "Unable to remove or write to empty PID file. Start aborted."
            exit 1
          fi
        fi
      fi
    fi
  fi
}

merge_conf() {
    local PROGRAM="$1"
    local DEST="$2"
    if [ -d "$APP_HOME/conf/$PROGRAM" ]; then
        echo "merge $PROGRAM conf..." >> "${CATALINA_OUT}"
        rsync -av --itemize-changes "$APP_HOME/conf/$PROGRAM/" "$DEST/" >> "${CATALINA_OUT}" || exit
    fi
}

prepare_catalina_base() {
    rm -rf "$CATALINA_BASE" || exit
    mkdir -p "$CATALINA_BASE" "$CATALINA_BASE/"{temp,work} || exit
    cp -rf "$CATALINA_HOME/conf" "$CATALINA_BASE/" || exit
    #自定义配置与tomcat配置合并或替换
    merge_conf "tomcat" "$CATALINA_BASE/conf"
    sed -i -e "s/\"8080\"/\"$TOMCAT_PORT\"/g" $CATALINA_BASE/conf/server.xml
    sed -i -e "s/\"8005\"/\"$((TOMCAT_PORT+1000))\"/g" $CATALINA_BASE/conf/server.xml
    #forece set /status.ok to default servlet
 #   sed -i -e 's/<url-pattern>\/<\/url-pattern>/<url-pattern>\/<\/url-pattern>\n\t<url-pattern>\/status.ok<\/url-pattern>/' $CATALINA_BASE/conf/web.xml
    add_root_context
}

add_root_context(){
    mkdir -p "$CATALINA_BASE/conf/Catalina"
    mkdir -p "$CATALINA_BASE/conf/Catalina/localhost"
    ROOT_FILE="$CATALINA_BASE/conf/Catalina/localhost/ROOT.xml"
    if [ ! -f $ROOT_FILE ];then
        touch "$ROOT_FILE"
        echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Context path=\"\" docBase=\"$APP_HOME/deploy/${APP_NAME}.war\" />" > $ROOT_FILE
    fi

}


update_war() {
    local war_name=$1
    local war_package=${APP_HOME}/target/${war_name}.tgz
    local war_dir=${APP_HOME}/deploy/${war_name}

    if [ -f $war_package ];then
        rm -rf ${APP_HOME}/deploy/*
        echo "extract ${war_package} to ${war_dir} ..."
        tar xzf  $war_package  -C ${APP_HOME}/deploy/
        if [ $? -ne 0 ];then
           echo "ERROR:解压 $APP_HOME/target/${APP_NAME}.tgz 失败"
           return 1
        fi
    else
         echo "WARNNING:not found war package ${war_package}.不解压"
    fi

    if [ -d "${APP_HOME}/deploy/${war_name}.war" ]; then
        rm -f $CATALINA_BASE/deploy
       ##  ln -s "${APP_HOME}/deploy" "$CATALINA_BASE/deploy"
    else
        echo "ERROR: not found ${APP_HOME}/deploy/${war_name}.war"
        return 1
    fi
}

start() {
    ls -t "$CATALINA_OUT".* 2>/dev/null | awk '{if(NR>10)print}' | xargs --no-run-if-empty rm -f
    if [ -e "$CATALINA_OUT" ]; then
        mv "$CATALINA_OUT" "$CATALINA_OUT.$(date '+%Y%m%d%H%M%S')" || exit
    fi
    mkdir -p "$(dirname "${CATALINA_OUT}")" || exit
    touch "$CATALINA_OUT" || exit


    do_start | tee -a "${CATALINA_OUT}"
    if ! { test -r "${CATALINA_PID}" && kill -0 "$(cat "${CATALINA_PID}")"; }; then
        exit 1
    fi
}

do_start() {
    check_catalina_pid
    prepare_catalina_base
    mkdir -p "${APP_HOME}/target" || exit
    mkdir -p "${APP_HOME}/logs" || exit

    update_war "${APP_NAME}" || exit

    echo "start tomcat"

    "$CATALINA_HOME"/bin/catalina.sh start >> "${CATALINA_OUT}"
}

# 用于LB 7layer 或者 nginx upstream  健康检查
online() {
    touch -m $STATUSROOT_HOME/status.ok || exit
    echo "app auto online..."
}


# 用于LB 7layer 或者 nginx upstream  健康检查
offline() {
    rm -f $STATUSROOT_HOME/status.ok || exit
    echo "wait app offline..."
    for e in $(seq 15); do
        echo -n " $e"
        sleep 1
    done
    echo
}


stop() {
    offline
    if [ "${NGINX_SKIP}" -ne "1" ]; then
        echo "stop nginx"
        "$NGINXCTL" stop
    fi
    echo "stop tomcat"
    if [ -f "$CATALINA_PID" ]; then
        local PID=$(cat "$CATALINA_PID")
        if kill -0 "$PID" 2>/dev/null; then

            #  stop -force       Stop Catalina, wait up to 5 seconds and then use kill -KILL if still running"
            "$CATALINA_HOME"/bin/catalina.sh stop -force
            mv ${JAVA_LOGS}/gc.log ${JAVA_LOGS}/gc.log.`date +%Y%m%d%H%M%S`

        fi
    fi
}

backup() {
    if [ -f "${APP_HOME}/target/${APP_NAME}.tgz" ]; then
        mkdir -p "${APP_HOME}/target/backup" || exit
        war_time=$(date --reference "${APP_HOME}/target/${APP_NAME}.tgz" +"%Y%m%d%H%M%S")
        cp -f "${APP_HOME}/target/${APP_NAME}.tgz" "${APP_HOME}/target/backup/${APP_NAME}.tgz.${war_time}"
        ls -t "${APP_HOME}/target/backup/${APP_NAME}.tgz".* 2>/dev/null | awk '{if(NR>3)print}' | xargs --no-run-if-empty rm -f
    fi
}

start_http() {
    exptime=0
    local PID=$(cat "$CATALINA_PID")
    for (( i=0;  i<300;  i=i+1 )) do
        ret=`egrep "(startup failed due to previous errors|Cannot start server)" $CATALINA_OUT`
        if [ ! -z "$ret" ] || ! kill -0 "$PID" 2>/dev/null; then
            echo -e "\nTomcat startup failed."
            return 1
        fi
        ret=`fgrep "Server startup in" $CATALINA_OUT`
        if [ -z "$ret" ]; then
            sleep 1
            ((exptime++))
            echo -n -e "\rWait Tomcat Start: $exptime..."
        else
           echo
           touch -m $STATUSROOT_HOME/status.ok
           if [ ! -f $STATUSROOT_HOME/status.ok ];then
                 echo "can't create status file, please check directory and disk space, not online"
            else
                 echo "created status file success"
            fi
            . "$APP_HOME/bin/check_ok.sh"
           if [ $status -eq 2 ]; then
              echo "app start success, check status.ok success"
           elif [ $status -eq 1 ]; then
              echo "app start success, check status.ok failed"
              exit 1
            else
               echo "app start failed. please check log and fix it"
               exit 1
            fi
            if [ "${NGINX_SKIP}" -ne "1" ]; then
                echo "start nginx"
                "$NGINXCTL" start
                if [ "$?" == "0" ]; then
                    echo "HTTP Start SUCCESS."
                else
                    echo "HTTP Start Failed."
                    exit 1
                fi
            fi
            # 用来保证透过 nginx proxy访问健康检查也是正常的
            #if test -n "${STATUS_PORT}"; then
            #    sleep 3
            #    status_code=`/usr/bin/curl -o /dev/null --connect-timeout 5 -s -w %{http_code}  "http://127.0.0.1:${STATUS_PORT}/${APP_NAME}/status.ok"`
            #    if [ x$status_code != x200 ];then
            #        echo "check http://127.0.0.1:${STATUS_PORT}/${APP_NAME}/status.ok failed"
            #        exit 1
            #    fi
            #    echo "app online success"
            #fi
            return
        fi
    done
    echo "tomcat startup timeout."
    exit 1
}

case "$ACTION" in
    start)
        start
        start_http
    ;;
    stop)
        stop
    ;;
    online)
        online
    ;;
    offline)
        offline
    ;;
    restart)
        stop
        start
        start_http
    ;;
    pubstart)
        stop
        start
        start_http
        backup
    ;;
    *)
        usage
    ;;
esac

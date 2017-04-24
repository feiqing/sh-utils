# 设置 ${APP_NAME} 不设就是 目录名
APP_NAME=
NGINX_HOME=/home/www/tengine
HOME="$(getent passwd "$UID" | awk -F":" '{print $6}')" # fix "$HOME" by "$UID"
JAVA_LOGS="${APP_HOME}/logs"

# 设置env 保证与os env无关
export LANG=zh_CN.UTF-8
export JAVA_FILE_ENCODING=UTF-8
export JAVA_HOME=/usr/local/java
export CPU_COUNT="$(grep -c 'cpu[0-9][0-9]*' /proc/stat)"
ulimit -c unlimited

# 可能需要重启 nginx, 设成1跳过启动nginx
test -z "$NGINX_SKIP" && NGINX_SKIP=1


export CATALINA_HOME=/usr/local/tomcat
export CATALINA_BASE=$APP_HOME/.server
export CATALINA_LOGS=$APP_HOME/logs/catalina
export CATALINA_OUT=$APP_HOME/logs/tomcat_stdout.log
export CATALINA_PID=$CATALINA_BASE/catalina.pid

# tomcat 的http port,建议设在这里
export TOMCAT_PORT=8080
export STATUS_PORT=$TOMCAT_PORT

# tomcat jvm options
CATALINA_OPTS="-server" 
CATALINA_OPTS="${CATALINA_OPTS} -Xms5g -Xmx5g"
CATALINA_OPTS="${CATALINA_OPTS} -XX:PermSize=256m -XX:MaxPermSize=256m"
CATALINA_OPTS="${CATALINA_OPTS} -Xmn2g"
CATALINA_OPTS="${CATALINA_OPTS} -XX:MaxDirectMemorySize=512m"
CATALINA_OPTS="${CATALINA_OPTS} -XX:SurvivorRatio=8"
CATALINA_OPTS="${CATALINA_OPTS} -XX:+UseConcMarkSweepGC -XX:+UseCMSCompactAtFullCollection -XX:CMSMaxAbortablePrecleanTime=5000"
CATALINA_OPTS="${CATALINA_OPTS} -XX:+CMSClassUnloadingEnabled -XX:CMSInitiatingOccupancyFraction=80 -XX:+UseCMSInitiatingOccupancyOnly"
CATALINA_OPTS="${CATALINA_OPTS} -XX:+ExplicitGCInvokesConcurrent -Dsun.rmi.dgc.server.gcInterval=2592000000 -Dsun.rmi.dgc.client.gcInterval=2592000000"
CATALINA_OPTS="${CATALINA_OPTS} -XX:ParallelGCThreads=${CPU_COUNT}"
CATALINA_OPTS="${CATALINA_OPTS} -Xloggc:${JAVA_LOGS}/gc.log -XX:+PrintGCDetails -XX:+PrintGCDateStamps"
CATALINA_OPTS="${CATALINA_OPTS} -XX:+HeapDumpBeforeFullGC -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=${JAVA_LOGS}/java.hprof"
CATALINA_OPTS="${CATALINA_OPTS} -Djava.awt.headless=true"
CATALINA_OPTS="${CATALINA_OPTS} -Dsun.net.client.defaultConnectTimeout=10000"
CATALINA_OPTS="${CATALINA_OPTS} -Dsun.net.client.defaultReadTimeout=30000"
CATALINA_OPTS="${CATALINA_OPTS} -Dfile.encoding=${JAVA_FILE_ENCODING}"

Ip=`/sbin/ifconfig |awk '/inet addr:/{print $2}'|cut -d":" -f 2|head -n 1`
#设置JMX,线上环境监控JVM需要
CATALINA_OPTS="${CATALINA_OPTS} -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=$((TOMCAT_PORT+2)) -Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false -Djava.rmi.server.hostname=$Ip"

export CATALINA_OPTS

if [ -z "$APP_NAME" ]; then
	APP_NAME=$(basename "${APP_HOME}")
fi
if [ -z "$NGINX_HOME" ]; then
	NGINX_HOME=/home/www/tengine
    NGINXCTL=$NGINX_HOME/bin/nginxctl
fi

#
STATUSROOT_HOME="${APP_HOME}/deploy/${APP_NAME}.war"

# 能getProperties 取到应用名，也许以后用的着
CATALINA_OPTS="$CATALINA_OPTS -Dproject.name=$APP_NAME"


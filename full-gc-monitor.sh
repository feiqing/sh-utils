#!/bin/sh
#****************************************************************#
# ScriptName: full-gc-monitor.sh
# Create Date: 2017-02-09 14:46
# Modify Date: 2017-02-09 14:46
#***************************************************************#

if [ ! -d "~/oldspace.txt" ] ; then
    touch ~/oldspace.txt
fi

monitorCount=`jobs -l | grep 'sh full-gc-monitor.sh &' -c`
if [ "$monitorCount" != "1"  ] ; then
    pid=`jps | grep Bootstrap | awk '{print $1}'`
    while true
    do
        oldOccupation=`jstat -gcutil ${pid} 1 1 | tail -n 1 | awk '{print $4}'`
        time=`date "+%Y-%m-%d %H:%M:%S"`
        echo $time - $oldOccupation >> oldspace.txt
        sleep 1m
    done
fi

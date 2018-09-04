#!/bin/bash
set -e
cd /go/src/github.com/hyperledger/fabric-orderingservice;
cat config/node.config > /data/replica-config-${NUMBER}.config
if [ -f ./config/currentView ]; then
rm -f ./config/currentView
fi
if [ $NUMBER -eq 1 ] ; then
while [ ! -f /data/logs/replica-test-0.log ] ; do
 sleep 2
done
fi
if [ $NUMBER -eq 2 ] ; then
while [ ! -f /data/logs/replica-test-1.log ] ; do
 sleep 2
done
fi
if [ $NUMBER -eq 3 ] ; then
while [ ! -f /data/logs/replica-test-2.log ] ; do
 sleep 2
done
fi
echo $JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 && ./startReplica.sh $NUMBER
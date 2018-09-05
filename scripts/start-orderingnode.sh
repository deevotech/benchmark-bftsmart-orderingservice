#!/bin/bash
set -e
while [ ! -f /data/logs/setup.successful ] ; do
 sleep 2
done
cp /data/genesis.block /etc/bftsmart-orderer/config/genesisblock
cd /go/src/github.com/hyperledger/fabric-orderingservice;
cat config/node.config > /data/orderingnode-config-${NUMBER}.config
if [ -f ./config/currentView ]; then
rm -f ./config/currentView
fi
if [ $NUMBER -eq 1 ] ; then
while [ ! -f /data/logs/orderingnode-0.log ] ; do
 sleep 2
done
fi
if [ $NUMBER -eq 2 ] ; then
while [ ! -f /data/logs/orderingnode-1.log ] ; do
 sleep 2
done
fi
if [ $NUMBER -eq 3 ] ; then
while [ ! -f /data/logs/orderingnode-2.log ] ; do
 sleep 2
done
fi
echo $JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 && ./startReplica.sh $NUMBER
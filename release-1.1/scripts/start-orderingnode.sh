#!/bin/bash
set -e
while [ ! -f /data/logs/setup.successful ] ; do
 sleep 2
done
cp /data/genesis.block /etc/bftsmart-orderer/config/genesisblock
cp /data/key.pem /etc/bftsmart-orderer/config/key.pem
cp /data/peer.pem /etc/bftsmart-orderer/config/peer.pem
cp /data/node.config /etc/bftsmart-orderer/config/node.config
cp /config/hosts.config /etc/bftsmart-orderer/config/hosts.config

cp /data/key.pem /go/src/github.com/hyperledger/fabric-orderingservice/config/key.pem
cp /data/peer.pem /go/src/github.com/hyperledger/fabric-orderingservice/config/peer.pem
cp /data/node.config /go/src/github.com/hyperledger/fabric-orderingservice/config/node.config
cp /config/hosts.config /go/src/github.com/hyperledger/fabric-orderingservice/config/hosts.config
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
touch /data/logs/all.ordering.node.success
fi

echo $JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 && ./startReplica.sh $NUMBER
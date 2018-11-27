#!/bin/bash

SDIR=$(dirname "$0")
source $SDIR/env.sh
export RUN_SUMPATH=/data/logs/replica-${NUMBER}.log

logr "wait for genesis block"
sleep 62

cd $GOPATH/src/github.com/hyperledger/fabric-orderingservice
rm -rf config/currentView
rm -rf config/keys/*
cp /config/hosts.config config/hosts.config
cp /config/node.config config/node.config
cp /config/system.config config/system.config
sed -i "s/MSPID=org0MSP/MSPID=ordering-nodesMSP/g" config/node.config

# Copy certs
cp /crypto-config-orderer/tls/server.crt config/keys/cert1000.pem
for ((c = 0; c < $NODE_COUNT; c++)); do
	NODE_HOST_NAME="bft.node.${c}"
	cp /crypto-config/$NODE_HOST_NAME/tls/client.crt config/keys/cert${c}.pem
done
# Copy private key
NODE_HOST_NAME="bft.node.${NUMBER}"
cp /crypto-config/$NODE_HOST_NAME/tls/client.key config/keys/keystore.pem

logr $(ls config/keys)

./startReplica.sh $NUMBER 2>&1 | tee -a $RUN_SUMPATH

#!/bin/bash

SDIR=$(dirname "$0")
source $SDIR/env.sh
export RUN_SUMPATH=/data/logs/network/replica-${NUMBER}.log

declare -A NODES='('${NODE_COUNT}')'

cd $GOPATH/src/github.com/hyperledger/fabric-orderingservice
rm -rf config/currentView
rm -rf config/keys/*
cp -f /config/hosts.config config/hosts.config
cp -f /config/node.config config/node.config
cp -f /config/system.config config/system.config

NODES_CRT_DIR=$LOCAL_MSP_DIR/$REPLICAS_ORG/certs
NODES_KEY_DIR=$LOCAL_MSP_DIR/$REPLICAS_ORG/keys

logr "Wait for genesis block"
sleep 20

# Copy certs
cp -r $NODES_CRT_DIR/* config/keys
# Copy private key
cp $NODES_KEY_DIR/cert${NUMBER}.key config/keys/keystore.pem

logr $(ls config/keys)

./startReplica.sh $NUMBER 2>&1 | tee -a $RUN_SUMPATH

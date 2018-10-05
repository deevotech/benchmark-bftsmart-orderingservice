#!/bin/bash

SDIR=$(dirname "$0")
source $SDIR/env.sh
export RUN_SUMPATH=/data/logs/replica-${NUMBER}.log

logr "wait for genesis block"
sleep 60

cd $GOPATH/src/github.com/hyperledger/fabric-orderingservice
rm -rf config/currentView
cp /config/hosts.config config/hosts.config 
cp /config/node.config config/node.config 
./startReplica.sh $NUMBER 2>&1 | tee -a  $RUN_SUMPATH
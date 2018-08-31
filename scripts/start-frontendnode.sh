#!/bin/bash

set -e
cd /go/src/github.com/hyperledger/fabric-orderingservice;
if [ -f ./config/currentView ]; then
rm -f ./config/currentView
fi
# start frontend
./startFrontend.sh 1000 10 9999 > /data/logs/frontend-0.success 2>&1 &
sleep 5
#dowait "genesis block to be created" 60 $SETUP_LOGFILE $ORDERER_GENERAL_GENESISFILE
while [ ! -f /data/logs/frontend-0.success ] ; do
 sleep 2
done
# Start the orderer
env | grep ORDERER > /data/orderer.config
env | grep ORDERER
orderer

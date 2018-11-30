#!/bin/bash

SDIR=$(dirname "$0")
export RUN_SUMPATH=/data/logs/network/peer$NUMBER.$ORG.log
source $SDIR/env.sh

function start-peer() {
	initPeerVars $ORG ${NUMBER}
	cp -f /config/core.yaml $FABRIC_CFG_PATH/core.yaml

	logr "Wait for genesis block and bft"
	sleep 50

	logr "Start peer"
	peer node start 2>&1 | tee -a $RUN_SUMPATH 
}

start-peer

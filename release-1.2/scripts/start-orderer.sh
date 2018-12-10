#!/bin/bash

SDIR=$(dirname "$0")
source $SDIR/env.sh
export RUN_SUMPATH=/data/logs/network/orderer.log
export RUN_FRONTEND=/data/logs/network/frontend.log

function start-orderer() {
	initOrdererVars $ORDERER_ORG ${NUMBER}
	cp -f /config/orderer.yaml $FABRIC_CFG_PATH/orderer.yaml
	cp -f /config/configtx.yaml $FABRIC_CFG_PATH/configtx.yaml

	logr "wait for genesis block and replicas"
	sleep 30

	logr "Start frontend"
	cd $GOPATH/src/github.com/hyperledger/fabric-orderingservice
	rm -rf config/currentView
	rm -rf config/keys/*

	NODES_CRT_DIR=$LOCAL_MSP_DIR/$REPLICAS_ORG/certs
	NODES_KEY_DIR=$LOCAL_MSP_DIR/$REPLICAS_ORG/keys

	# Copy certs
	cp -r $NODES_CRT_DIR/* config/keys
	# Copy private key
	cp $NODES_KEY_DIR/cert1000.key config/keys/keystore.pem

	logr $(ls config/keys)

	cp -f /config/hosts.config config/hosts.config
	cp -f /config/node.config config/node.config
	cp -f /config/system.config config/system.config

	./startFrontend.sh 1000 10 9999 2>&1 | tee -a $RUN_FRONTEND &

	logr "Wait for frontend"
	sleep 15

	logr "Start orderer"
	orderer start 2>&1 | tee -a $RUN_SUMPATH
}

start-orderer

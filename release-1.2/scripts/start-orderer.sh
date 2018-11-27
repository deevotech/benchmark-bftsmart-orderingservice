#!/bin/bash

SDIR=$(dirname "$0")
source $SDIR/env.sh
export RUN_SUMPATH=/data/logs/orderer.log
export RUN_FRONTEND=/data/logs/frontend.log

function enrollCAAdmin() {
	logr "Enrolling with $ENROLLMENT_URL as bootstrap identity ..."
	fabric-ca-client enroll -d -u $ENROLLMENT_URL
}

# Register any identities associated with a peer
function registerOrdererIdentities() {
	enrollCAAdmin

	fabric-ca-client register -d --id.name $CORE_PEER_ID --id.secret $ORDERER_PASS --id.type orderer --id.affiliation $ORG

	logr "Registering admin identity with $ADMIN_NAME:$ADMIN_PASS"
	# The admin identity has the "admin" attribute which is added to ECert by default
	fabric-ca-client register -d --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.attrs "admin=true:ecert" --id.affiliation $ORG
}

function registerNodesIdentities() {
	FABRIC_CA_CLIENT_HOME=/var/hyperledger/ordering/ca-client
	FABRIC_CA_CLIENT_TLS_CERTFILES=/etc/hyperledger/fabric-ca-server-ordering/rca.ordering.bft-cert.pem

	fabric-ca-client enroll -d -u https://rca-admin:rca-adminpw@$ORDERING_CA_HOST:7054
	NODE_ORG_ADMIN=ordering-nodes-admin
	NODE_ORG_ADMIN_PW=ordering-nodes-admin-pw

	ORDERING_ORG_MSP_DIR=$ORDERING_CRYPTO_DIR/msp
	mkdir -p $ORDERING_ORG_MSP_DIR
	fabric-ca-client getcacert -d -u https://rca-admin:rca-adminpw@$ORDERING_CA_HOST:7054 -M $ORDERING_ORG_MSP_DIR
	mkdir -p $ORDERING_ORG_MSP_DIR/tlscacerts
	cp $ORDERING_ORG_MSP_DIR/cacerts/* $ORDERING_ORG_MSP_DIR/tlscacerts

	logr "Registering admin identity with $NODE_ORG_ADMIN:$NODE_ORG_ADMIN_PW"
	# The admin identity has the "admin" attribute which is added to ECert by default
	fabric-ca-client register -d --id.name $NODE_ORG_ADMIN --id.secret $NODE_ORG_ADMIN_PW --id.attrs "admin=true:ecert" --id.affiliation $NODE_ORG

	ORDERING_ADMIN_MSP_DIR=$ORDERING_CRYPTO_DIR/admin/msp
	ORDERING_ADMIN_TLS_DIR=$ORDERING_CRYPTO_DIR/admin/tls
	mkdir -p $ORDERING_ADMIN_MSP_DIR
	mkdir -p $ORDERING_ADMIN_TLS_DIR
	genMSPCerts bft.node $NODE_ORG_ADMIN $NODE_ORG_ADMIN_PW $NODE_ORG $ORDERING_CA_HOST $ORDERING_ADMIN_MSP_DIR

	cp $ORDERING_ADMIN_MSP_DIR/signcerts/* $ORDERING_ADMIN_TLS_DIR/client.crt
	cp $ORDERING_ADMIN_MSP_DIR/keystore/* $ORDERING_ADMIN_TLS_DIR/client.key

	# Copy admin certs
	mkdir -p $ORDERING_ADMIN_MSP_DIR/admincerts
	cp $ORDERING_ADMIN_MSP_DIR/signcerts/* $ORDERING_ADMIN_MSP_DIR/admincerts/cert.pem
	mkdir -p $ORDERING_ORG_MSP_DIR/admincerts
	cp $ORDERING_ADMIN_MSP_DIR/signcerts/* $ORDERING_ORG_MSP_DIR/admincerts/cert.pem

	# create users for ordering nodes
	for ((c = 0; c < $NODE_COUNT; c++)); do
		NODE_HOST_NAME="bft.node.${c}"
		NODE_USER="node-${c}"
		NODE_PASS="node-${c}-pw"
		fabric-ca-client register -d --id.name $NODE_USER --id.secret $NODE_PASS --id.affiliation $NODE_ORG

		ORDERING_NODE_MSP_DIR=$ORDERING_CRYPTO_DIR/$NODE_HOST_NAME/msp
		ORDERING_NODE_TLS_DIR=$ORDERING_CRYPTO_DIR/$NODE_HOST_NAME/tls

		mkdir -p $ORDERING_CRYPTO_DIR/$NODE_HOST_NAME
		genMSPCerts $NODE_HOST_NAME $NODE_USER $NODE_PASS $ORG $ORDERING_CA_HOST $ORDERING_NODE_MSP_DIR

		mkdir -p $ORDERING_NODE_TLS_DIR
		cp $ORDERING_NODE_MSP_DIR/signcerts/* $ORDERING_NODE_TLS_DIR/client.crt
		cp $ORDERING_NODE_MSP_DIR/keystore/* $ORDERING_NODE_TLS_DIR/client.key
		# Copy admin certs
		mkdir -p $ORDERING_NODE_MSP_DIR/admincerts
		cp $ORDERING_ADMIN_MSP_DIR/signcerts/* $ORDERING_NODE_MSP_DIR/admincerts/cert.pem
	done
}

function getCACerts() {
	logr "Getting CA certificates ..."
	logr "Getting CA certs for organization $ORG and storing in $ORG_MSP"
	mkdir -p $ORG_MSP
	fabric-ca-client getcacert -d -u $ENROLLMENT_URL -M $ORG_MSP
	mkdir -p $ORG_MSP/tlscacerts
	cp $ORG_MSP/cacerts/* $ORG_MSP/tlscacerts

	# Copy CA cert
	mkdir -p $FABRIC_CA_CLIENT_HOME/msp/tlscacerts
	cp $ORG_MSP/cacerts/* $FABRIC_CA_CLIENT_HOME/msp/tlscacerts
}

function main() {
	logr "wait for ca server"
	sleep 20

	mkdir -p FABRIC_CA_CLIENT_HOME

	registerOrdererIdentities
	getCACerts
	logr "Finished create certificates"
	logr "Start create TLS"

	logr "Enroll again to get the orderer's enrollment certificate (default profile)"
	genMSPCerts $CORE_PEER_ID $CORE_PEER_ID $ORDERER_PASS $ORG $CA_HOST $ORDERER_CERT_DIR/msp

	mkdir -p $ORDERER_CERT_DIR/tls
	cp $ORDERER_CERT_DIR/msp/signcerts/* $ORDERER_GENERAL_TLS_CERTIFICATE
	cp $ORDERER_CERT_DIR/msp/keystore/* $ORDERER_GENERAL_TLS_PRIVATEKEY

	if [ $ADMINCERTS ]; then
		logr "Generate client TLS cert and key pair for the peer CLI"
		genMSPCerts $CORE_PEER_ID $ADMIN_NAME $ADMIN_PASS $ORG $CA_HOST $ADMIN_CERT_DIR/msp

		cp $ADMIN_CERT_DIR/msp/signcerts/* $ADMIN_CERT_DIR/tls/client.crt
		cp $ADMIN_CERT_DIR/msp/keystore/* $ADMIN_CERT_DIR/tls/client.key
		mkdir -p $ADMIN_CERT_DIR/msp/admincerts
		cp $ADMIN_CERT_DIR/msp/signcerts/* $ADMIN_CERT_DIR/msp/admincerts/cert.pem
		logr "Copy the org's admin cert into some target MSP directory"

		mkdir -p $ORDERER_CERT_DIR/msp/admincerts
		cp $ADMIN_CERT_DIR/msp/signcerts/* $ORDERER_CERT_DIR/msp/admincerts/cert.pem

		mkdir -p $ORG_MSP/admincerts
		cp $ADMIN_CERT_DIR/msp/signcerts/* $ORG_MSP/admincerts/admin-cert.pem
		cp $ORDERER_CERT_DIR/msp/signcerts/* $ORG_MSP/admincerts/orderer-cert.pem
	fi

	logr "Finished create TLS"

	cp /config/orderer.yaml $FABRIC_CFG_PATH/orderer.yaml

	registerNodesIdentities

	logr "wait for genesis block and replicas"
	sleep 50

	logr "Start frontend"
	cd $GOPATH/src/github.com/hyperledger/fabric-orderingservice
	rm -rf config/currentView
	rm -rf config/keys/*

	# Copy certs
	cp $ORDERER_CERT_DIR/tls/server.crt config/keys/cert1000.pem
	for ((c = 0; c < $NODE_COUNT; c++)); do
		NODE_HOST_NAME="bft.node.${c}"
		cp $ORDERING_CRYPTO_DIR/$NODE_HOST_NAME/tls/client.crt config/keys/cert${c}.pem
	done
	# Copy private key
	cp $ORDERER_CERT_DIR/tls/server.key config/keys/keystore.pem

	logr $(ls config/keys)

	cp /config/hosts.config config/hosts.config
	cp /config/node.config config/node.config
	cp /config/system.config config/system.config

	./startFrontend.sh 1000 10 9999 2>&1 | tee -a $RUN_FRONTEND &

	logr "Wait for genesis block and bft"
	sleep 20

	logr "Start orderer"
	orderer start 2>&1 | tee -a $RUN_SUMPATH
}

main

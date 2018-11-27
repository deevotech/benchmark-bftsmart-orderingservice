#!/bin/bash

FABRIC_ORGS="replicas org0 org1 org2"
ORDERER_ORG=org0
ORDERER_HOST=orderer0.${ORDERER_ORG}.bft
export ROOT_CRYPTO_DIR=/etc/hyperledger/fabric/crypto-config

# initOrgVars <ORG>
function initOrgVars() {
	if [ $# -ne 1 ]; then
		echo "Usage: initOrgVars <ORG>"
		exit 1
	fi
	ORG=$1
	ROOT_CA_HOST=rca.${ORG}.bft
	ROOT_CA_NAME=rca.${ORG}.bft

	# Admin identity for the org
	ADMIN_NAME=admin-${ORG}
	ADMIN_PASS=${ADMIN_NAME}pw
	# Typical user identity for the org
	USER_NAME=user-${ORG}
	USER_PASS=${USER_NAME}pw

	# Root CA admin identity
	ROOT_CA_ADMIN_USER_PASS=rca-admin:rca-adminpw

	export ROOT_CA_CERTFILE=$ROOT_CRYPTO_DIR/orgs/${ORG}/ca/rca.${ORG}.bft-cert.pem
	export ROOT_TLS_CERTFILE=$ROOT_CRYPTO_DIR/orgs/${ORG}/ca/tls.rca.${ORG}.bft-cert.pem

	mkdir -p $ARTIFACT_DIR/${ORG}

	ANCHOR_TX_FILE=$ARTIFACT_DIR/${ORG}/anchors.tx
	ORG_MSP_ID=${ORG}MSP
	ORG_MSP_DIR=$ROOT_CRYPTO_DIR/orgs/${ORG}/msp
	ORG_ADMIN_CERT=${ORG_MSP_DIR}/admincerts/cert.pem
	# ORG_ADMIN_HOME=${DATA}/orgs/$ORG/admin

	export CA_NAME=$ROOT_CA_NAME
	export CA_HOST=$ROOT_CA_HOST
	export CA_CHAINFILE=$ROOT_TLS_CERTFILE
	# export CA_CHAINFILE=$ROOT_CA_CERTFILE
	export CA_ADMIN_USER_PASS=$ROOT_CA_ADMIN_USER_PASS
	export ENROLLMENT_URL=https://$ROOT_CA_ADMIN_USER_PASS@$ROOT_CA_HOST:7054

	export USER_CERT_DIR=$ROOT_CRYPTO_DIR/orgs/$ORG/user
	export ADMIN_CERT_DIR=$ROOT_CRYPTO_DIR/orgs/$ORG/admin
}

# initPeerVars <ORG> <NUM>
function initPeerVars() {
	if [ $# -ne 2 ]; then
		echo "Usage: initPeerVars <ORG> <NUM>: $*"
		exit 1
	fi
	ORG=$1
	NUM=$2

	initOrgVars $1
	export PEER_HOST=peer${NUM}.${ORG}.bft
	export PEER_NAME=peer${NUM}.${ORG}.bft
	export PEER_PASS=${PEER_NAME}pw

	cp /config/core.yaml $FABRIC_CFG_PATH/core.yaml

	export PEER_CERT_DIR=$ROOT_CRYPTO_DIR/orgs/$ORG/$PEER_NAME
	export FABRIC_CA_CLIENT_HOME=/etc/ca-client

	export CORE_PEER_ID=$PEER_HOST
	export CORE_PEER_ADDRESS=$PEER_HOST:7051
	export CORE_PEER_LOCALMSPID=$ORG_MSP_ID
	export CORE_PEER_MSPCONFIGPATH=$PEER_CERT_DIR/msp
	export CORE_LOGGING_LEVEL=debug
	export CORE_PEER_TLS_ENABLED=true
	export CORE_PEER_TLS_CLIENTAUTHREQUIRED=true
	export CORE_PEER_TLS_ROOTCERT_FILE=$CA_CHAINFILE
	export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
	export CORE_PEER_TLS_CLIENTROOTCAS_FILES=$CA_CHAINFILE
	export PEER_GOSSIP_SKIPHANDSHAKE=true

	PEER_TLS_DIR=$PEER_CERT_DIR/tls
	export CORE_PEER_TLS_KEY_FILE=$PEER_TLS_DIR/server.key
	export CORE_PEER_TLS_CERT_FILE=$PEER_TLS_DIR/server.crt

	ADMIN_TLS_DIR=$ADMIN_CERT_DIR/tls
	export CORE_PEER_TLS_CLIENTCERT_FILE=$ADMIN_TLS_DIR/client.crt
	export CORE_PEER_TLS_CLIENTKEY_FILE=$ADMIN_TLS_DIR/client.key

	export CORE_PEER_PROFILE_ENABLED=true
	# gossip variables
	export CORE_PEER_GOSSIP_USELEADERELECTION=true
	export CORE_PEER_GOSSIP_ORGLEADER=false
	export CORE_PEER_GOSSIP_EXTERNALENDPOINT=$PEER_HOST:7051
	if [ $NUM -gt 0 ]; then
		# Point the non-anchor peers to the anchor peer, which is always the 1st peer
		export CORE_PEER_GOSSIP_BOOTSTRAP=peer0.${ORG}.bft:7051
		export CORE_PEER_ADDRESSAUTODETECT=true
	fi

	export ORDERER_TLS_CA=$ROOT_CRYPTO_DIR/orgs/${ORDERER_ORG}/ca/tls.rca.${ORDERER_ORG}.bft-cert.pem
	export ORDERER_PORT_ARGS="-o $ORDERER_HOST:7050 --tls --cafile $ORDERER_TLS_CA --clientauth"

	export ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"
}

# log a message
function log() {
	if [ "$1" = "-n" ]; then
		shift
		echo -n "##### $(date '+%Y-%m-%d %H:%M:%S') $*"
	else
		echo "##### $(date '+%Y-%m-%d %H:%M:%S') $*"
	fi
}

function logr() {
	log $*
	log $* >>$RUN_SUMPATH
}

# fatal a message
function fatal() {
	logr "FATAL: $*"
	exit 1
}

function genMSPCerts() {
	if [ $# -ne 6 ]; then
		echo "Usage: genMSPCerts <host name> <name> <password> <org> <ca host> <msp dir>: $*"
		exit 1
	fi

	HOST_NAME=$1
	NAME=$2
	PASSWORD=$3
	ORG=$4
	CA_HOST_NAME=$5
	MSP_DIR=$6

	logr "Enroll to get certs of ${NAME} on ${CA_HOST_NAME}"

	mkdir -p $MSP_DIR
	rm -rf $MSP_DIR/*

	fabric-ca-client enroll -d --enrollment.profile tls -u https://$NAME:$PASSWORD@$CA_HOST_NAME:7054 -M $MSP_DIR --csr.hosts $HOST_NAME
}

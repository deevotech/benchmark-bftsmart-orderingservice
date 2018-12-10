#!/bin/bash

ORDERER_HOST=orderer0.${ORDERER_ORG}.deevo.io
ALL_ORGS=(${REPLICAS_ORG} ${ORDERER_ORG} ${PEER_ORGS[*]})

# initOrgVars <ORG>
function initOrgVars() {
	if [ $# -ne 1 ]; then
		echo "Usage: initOrgVars <ORG>"
		exit 1
	fi
	local ORG=$1
	ROOT_CA_HOST=rca.${ORG}.deevo.io
	ROOT_CA_NAME=rca.${ORG}.deevo.io

	# Admin identity for the org
	ADMIN_NAME=admin-${ORG}
	ADMIN_PASS=${ADMIN_NAME}pw
	# Typical user identity for the org
	USER_NAME=user-${ORG}
	USER_PASS=${USER_NAME}pw

	# Root CA admin identity
	ROOT_CA_ADMIN_USER_PASS=rca-admin:rca-adminpw

	export ROOT_CA_CERTFILE=$CRYPTO_DIR/cacerts/${ORG}/rca.${ORG}.deevo.io-cert.pem
	export ROOT_TLS_CERTFILE=$CRYPTO_DIR/cacerts/${ORG}/tls.rca.${ORG}.deevo.io-cert.pem

	ANCHOR_TX_FILE=$ARTIFACT_DIR/${ORG}/anchors.tx
	ORG_MSP_ID=${ORG}MSP
	ORG_MSP_DIR=$CHANNEL_MSP_DIR/${ORG}/msp
	# ORG_ADMIN_CERT=${ORG_MSP_DIR}/admincerts/cert.pem
	# ORG_ADMIN_HOME=${DATA}/orgs/$ORG/admin

	export CA_NAME=$ROOT_CA_NAME
	export CA_HOST=$ROOT_CA_HOST
	export CA_CHAINFILE=$ROOT_CA_CERTFILE
	export CA_ADMIN_USER_PASS=$ROOT_CA_ADMIN_USER_PASS
	export ENROLLMENT_URL=https://$ROOT_CA_ADMIN_USER_PASS@$ROOT_CA_HOST:7054
	export FABRIC_CA_CLIENT_TLS_CERTFILES=$ROOT_CA_CERTFILE
	export FABRIC_CA_CLIENT_HOME=$CRYPTO_DIR/orgs/$ORG/ca-client

	export ADMIN_CERT_DIR=$LOCAL_MSP_DIR/$ORG/users/admin
	export USER_CERT_DIR=$LOCAL_MSP_DIR/$ORG/users/user
}

# initOrgAndCAVars <ORG>
function initOrgAndCAVars() {
	if [ $# -ne 2 ]; then
		echo "Usage: initOrgAndCAVars <ORG> <CAORG>"
		exit 1
	fi
	local ORG=$1
	local CA_ORG=$2

	ROOT_CA_HOST=rca.${CA_ORG}.deevo.io
	ROOT_CA_NAME=rca.${CA_ORG}.deevo.io

	# Admin identity for the org
	ADMIN_NAME=admin-${ORG}
	ADMIN_PASS=${ADMIN_NAME}pw
	# Typical user identity for the org
	USER_NAME=user-${ORG}
	USER_PASS=${USER_NAME}pw

	# Root CA admin identity
	ROOT_CA_ADMIN_USER_PASS=rca-admin:rca-adminpw

	export ROOT_CA_CERTFILE=$CRYPTO_DIR/cacerts/${CA_ORG}/rca.${CA_ORG}.deevo.io-cert.pem
	export ROOT_TLS_CERTFILE=$CRYPTO_DIR/cacerts/${CA_ORG}/tls.rca.${CA_ORG}.deevo.io-cert.pem

	ANCHOR_TX_FILE=$ARTIFACT_DIR/${ORG}/anchors.tx
	ORG_MSP_ID=${ORG}MSP
	ORG_MSP_DIR=$CHANNEL_MSP_DIR/${ORG}/msp

	export CA_NAME=$ROOT_CA_NAME
	export CA_HOST=$ROOT_CA_HOST
	export CA_CHAINFILE=$ROOT_CA_CERTFILE
	export CA_ADMIN_USER_PASS=$ROOT_CA_ADMIN_USER_PASS
	export ENROLLMENT_URL=https://$ROOT_CA_ADMIN_USER_PASS@$ROOT_CA_HOST:7054
	export FABRIC_CA_CLIENT_TLS_CERTFILES=$ROOT_CA_CERTFILE
	export FABRIC_CA_CLIENT_HOME=$CRYPTO_DIR/orgs/$ORG/ca-client

	export ADMIN_CERT_DIR=$LOCAL_MSP_DIR/$ORG/users/admin
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
	export PEER_HOST=peer${NUM}.${ORG}.deevo.io
	export PEER_NAME=peer${NUM}.${ORG}.deevo.io
	export PEER_PASS=${PEER_NAME}pw

	export PEER_CERT_DIR=$LOCAL_MSP_DIR/$ORG/$PEER_NAME
	# export FABRIC_CA_CLIENT_HOME=/etc/ca-client

	export CORE_PEER_ID=$PEER_HOST
	export CORE_PEER_ADDRESS=$PEER_HOST:7051
	export CORE_PEER_LOCALMSPID=$ORG_MSP_ID
	export CORE_PEER_MSPCONFIGPATH=$PEER_CERT_DIR/msp
	export CORE_LOGGING_LEVEL=debug
	export CORE_PEER_TLS_ENABLED=true
	export CORE_PEER_TLS_CLIENTAUTHREQUIRED=true
	export CORE_PEER_TLS_ROOTCERT_FILE=$CA_CHAINFILE
	export CORE_PEER_TLS_CLIENTROOTCAS_FILES=$CA_CHAINFILE
	export PEER_GOSSIP_SKIPHANDSHAKE=true

	PEER_TLS_DIR=$PEER_CERT_DIR/tls
	export CORE_PEER_TLS_KEY_FILE=$PEER_TLS_DIR/server.key
	export CORE_PEER_TLS_CERT_FILE=$PEER_TLS_DIR/server.crt

	export CORE_PEER_TLS_CLIENTCERT_FILE=$PEER_TLS_DIR/server.crt
	export CORE_PEER_TLS_CLIENTKEY_FILE=$PEER_TLS_DIR/server.key

	# ADMIN_TLS_DIR=$ADMIN_CERT_DIR/tls
	# export CORE_PEER_TLS_CLIENTCERT_FILE=$ADMIN_TLS_DIR/client.crt
	# export CORE_PEER_TLS_CLIENTKEY_FILE=$ADMIN_TLS_DIR/client.key

	export CORE_PEER_PROFILE_ENABLED=true
	# gossip variables
	export CORE_PEER_GOSSIP_USELEADERELECTION=true
	export CORE_PEER_GOSSIP_ORGLEADER=false
	export CORE_PEER_GOSSIP_EXTERNALENDPOINT=$PEER_HOST:7051
	if [ $NUM -gt 0 ]; then
		# Point the non-anchor peers to the anchor peer, which is always the 1st peer
		export CORE_PEER_GOSSIP_BOOTSTRAP=peer0.${ORG}.deevo.io:7051
		export CORE_PEER_ADDRESSAUTODETECT=true
	fi
}

function initPeerAdminCLI() {

	export CORE_PEER_MSPCONFIGPATH=$ADMIN_CERT_DIR/msp
	export CORE_PEER_TLS_CLIENTCERT_FILE=$ADMIN_CERT_DIR/tls/server.crt
	export CORE_PEER_TLS_CLIENTKEY_FILE=$ADMIN_CERT_DIR/tls/server.key

	export ORDERER_TLS_CA=$CRYPTO_DIR/cacerts/${ORDERER_ORG}/tls.${ORDERER_ORG}.pem
	export ORDERER_PORT_ARGS="-o $ORDERER_HOST:7050 --tls --cafile $ORDERER_TLS_CA --clientauth"
	export ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"
}

function initPeerUserCLI() {

	export CORE_PEER_MSPCONFIGPATH=$USER_CERT_DIR/msp
	export CORE_PEER_TLS_CLIENTCERT_FILE=$USER_CERT_DIR/tls/server.crt
	export CORE_PEER_TLS_CLIENTKEY_FILE=$USER_CERT_DIR/tls/server.key

	export ORDERER_TLS_CA=$CRYPTO_DIR/cacerts/${ORDERER_ORG}/tls.${ORDERER_ORG}.pem
	export ORDERER_PORT_ARGS="-o $ORDERER_HOST:7050 --tls --cafile $ORDERER_TLS_CA --clientauth"
	export ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"
}

# initOrdererVars <NUM>
function initOrdererVars() {
	if [ $# -ne 2 ]; then
		echo "Usage: initOrdererVars <ORG> <NUM>"
		exit 1
	fi
	initOrgVars $1
	local ORG=$1
	local NUM=$2

	export ORDERER_HOST=orderer${NUM}.${ORG}.deevo.io
	export ORDERER_NAME=orderer${NUM}.${ORG}.deevo.io
	export ORDERER_PASS=${ORDERER_NAME}pw
	export ORDERER_NAME_PASS=${ORDERER_NAME}:${ORDERER_PASS}

	export ORDERER_CERT_DIR=$LOCAL_MSP_DIR/$ORG/$ORDERER_NAME

	export ORDERER_GENERAL_LOGLEVEL=debug
	export ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
	export ORDERER_GENERAL_GENESISMETHOD=file
	export ORDERER_GENERAL_GENESISFILE=$GENESIS_BLOCK_FILE
	export ORDERER_GENERAL_LOCALMSPID=$ORG_MSP_ID
	export ORDERER_GENERAL_LOCALMSPDIR=$ORDERER_CERT_DIR/msp
	# enabled TLS
	export ORDERER_GENERAL_TLS_ENABLED=true
	export TLSDIR=$ORDERER_CERT_DIR/tls
	export ORDERER_GENERAL_TLS_PRIVATEKEY=$TLSDIR/server.key
	export ORDERER_GENERAL_TLS_CERTIFICATE=$TLSDIR/server.crt
	export ORDERER_GENERAL_TLS_ROOTCAS=[${ROOT_CAS}${CRYPTO_DIR}/cacerts/$ORG/tls.rca.$ORG.deevo.io-cert.pem]
	# export ORDERER_GENERAL_TLS_ROOTCAS=[$CA_CHAINFILE]
	# export ORDERER_GENERAL_TLS_CLIENTROOTCAS=[$CA_CHAINFILE]
	export ORDERER_HOME=/etc/hyperledger/orderer
	export ORDERER_GENERAL_LEDGERTYPE=file
	export ORDERER_FILELEDGER_LOCATION=/var/hyperledger/production/orderer

	export ORDERER_GENERAL_TLS_CLIENTAUTHREQUIRED=true
	# export ORDERER_TLS_CLIENTCERT_FILE=$TLSDIR/server.crt
	# export ORDERER_TLS_CLIENTKEY_FILE=$TLSDIR/server.key
	export ORDERER_GENERAL_TLS_CLIENTROOTCAS=[${ROOT_CAS}${CRYPTO_DIR}/cacerts/$ORG/tls.rca.$ORG.deevo.io-cert.pem]

	# local ROOT_CAS="["
	# for o in ${ALL_ORGS[*]}; do
	# 	ROOT_CAS="${ROOT_CAS}${CRYPTO_DIR}/cacerts/$o/tls.rca.$o.deevo.io-cert.pem,"
	# done
	# ROOT_CAS=${ROOT_CAS%?}
	# ROOT_CAS="$ROOT_CAS]"
}

function cleanOrCreateDirectory() {
	if [ $# -ne 1 ]; then
		echo "Usage: cleanOrCreateDirectory <path>: $*"
		exit 1
	fi

	if [ ! -d $1 ]; then
		mkdir -p $1
	else
		rm -rf $1/*
	fi
}

# log a message
function log() {
	if [ "$1" = "-n" ]; then
		shift
		echo -ne "\e[105m##### $(date '+%Y-%m-%d %H:%M:%S') ##### $*\e[0m"
	else
		echo -e "\e[105m##### $(date '+%Y-%m-%d %H:%M:%S') ##### $*\e[0m"
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

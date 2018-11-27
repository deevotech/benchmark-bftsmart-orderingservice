#!/bin/bash

SDIR=$(dirname "$0")
export RUN_SUMPATH=/data/logs/$CORE_PEER_ID.log
source $SDIR/env.sh

function enrollCAAdmin() {
	logr "Enrolling with $ENROLLMENT_URL as bootstrap identity ..."
	fabric-ca-client enroll -d -u $ENROLLMENT_URL
}

# Register any identities associated with a peer
function registerPeerIdentities() {
	enrollCAAdmin

	fabric-ca-client register -d --id.name $CORE_PEER_ID --id.secret $PEER_PASS --id.type peer --id.affiliation $ORG --id.attrs 'admin=true:ecert'

	logr "Registering admin identity with $ADMIN_NAME:$ADMIN_PASS"
	# The admin identity has the "admin" attribute which is added to ECert by default
	fabric-ca-client register -d --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.affiliation $ORG --id.attrs '"hf.Registrar.Roles=user"' --id.attrs '"hf.Registrar.Attributes=*"' --id.attrs 'hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,mycc.init=true:ecert'
	logr "Registering user identity with $USER_NAME:$USER_PASS"
	fabric-ca-client register -d --id.name $USER_NAME --id.secret $USER_PASS --id.affiliation $ORG --id.attrs '"hf.Registrar.Roles=user"'
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

	registerPeerIdentities
	getCACerts
	logr "Finished create certificates"
	logr "Start create TLS"

	mkdir -p $PEER_CERT_DIR
	logr "Generate server TLS cert and key pair for the peer"
	genMSPCerts $CORE_PEER_ID $CORE_PEER_ID $PEER_PASS $ORG $CA_HOST $PEER_CERT_DIR/msp

	mkdir -p $PEER_CERT_DIR/tls
	cp $PEER_CERT_DIR/msp/signcerts/* $CORE_PEER_TLS_CERT_FILE
	cp $PEER_CERT_DIR/msp/keystore/* $CORE_PEER_TLS_KEY_FILE

	logr "Generate client TLS cert and key pair for the user client"
	genMSPCerts $CORE_PEER_ID $USER_NAME $USER_PASS $ORG $CA_HOST $USER_CERT_DIR/msp

	cp $USER_CERT_DIR/msp/signcerts/* $CORE_PEER_TLS_CLIENTCERT_FILE
	cp $USER_CERT_DIR/msp/keystore/* $CORE_PEER_TLS_CLIENTKEY_FILE

	if [ $ADMINCERTS ]; then
		logr "Generate client TLS cert and key pair for the peer CLI"
		genMSPCerts $CORE_PEER_ID $ADMIN_NAME $ADMIN_PASS $ORG $CA_HOST $ADMIN_CERT_DIR/msp

		cp $ADMIN_CERT_DIR/msp/signcerts/* $PEER_CLI_TLS_CERT_FILE
		cp $ADMIN_CERT_DIR/msp/keystore/* $PEER_CLI_TLS_KEY_FILE
		mkdir -p $ADMIN_CERT_DIR/msp/admincerts
		cp $ADMIN_CERT_DIR/msp/signcerts/* $ADMIN_CERT_DIR/msp/admincerts/cert.pem
		logr "Copy the org's admin cert into some target MSP directory"

		mkdir -p $PEER_CERT_DIR/msp/admincerts
		cp $ADMIN_CERT_DIR/msp/signcerts/* $PEER_CERT_DIR/msp/admincerts/admin-user.pem
		cp $PEER_CERT_DIR/msp/signcerts/* $PEER_CERT_DIR/msp/admincerts/admin-peer.pem

		mkdir -p $USER_CERT_DIR/msp/admincerts
		cp $ADMIN_CERT_DIR/msp/signcerts/* $USER_CERT_DIR/msp/admincerts/admin-user.pem
		cp $PEER_CERT_DIR/msp/signcerts/* $USER_CERT_DIR/msp/admincerts/admin-peer.pem

		mkdir -p $ORG_MSP/admincerts
		cp $ADMIN_CERT_DIR/msp/signcerts/* $ORG_MSP/admincerts/admin-user.pem
		cp $PEER_CERT_DIR/msp/signcerts/* $ORG_MSP/admincerts/admin-peer.pem
	fi

	logr "Finished create TLS"

	cp /config/core.yaml $FABRIC_CFG_PATH/core.yaml

	logr "Wait for genesis block and bft"
	sleep 80

	logr "Start peer"
	peer node start 2>&1 | tee -a $RUN_SUMPATH 
}

main

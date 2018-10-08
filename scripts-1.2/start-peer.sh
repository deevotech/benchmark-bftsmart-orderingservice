#!/bin/bash

SDIR=$(dirname "$0")
export RUN_SUMPATH=/data/logs/$CORE_PEER_ID.log
source $SDIR/env.sh

function enrollCAAdmin() {
	logr "Enrolling with $ENROLLMENT_URL as bootstrap identity ..."
	fabric-ca-client enroll -d -u $ENROLLMENT_URL --csr.names C=US,ST="California",L="San Francisco",O=${ORG}
}

# Register any identities associated with a peer
function registerPeerIdentities() {
	enrollCAAdmin

	fabric-ca-client register -d --id.name $CORE_PEER_ID --id.secret $PEER_PASS --id.type peer

	logr "Registering admin identity with $ENROLLMENT_URL"
	# The admin identity has the "admin" attribute which is added to ECert by default
	fabric-ca-client register -d --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert,chaincode_example02.init=true:ecert,marbles02.init=true:ecert,supplychain.init=true:ecert"
	logr "Registering user identity with $ENROLLMENT_URL"
	fabric-ca-client register -d --id.name $USER_NAME --id.secret $USER_PASS
}

function getCACerts() {
	logr "Getting CA certificates ..."
	logr "Getting CA certs for organization $ORG and storing in $ORG_MSP"
	mkdir -p $ORG_MSP
	fabric-ca-client getcacert -d -u $ENROLLMENT_URL -M $ORG_MSP
	mkdir -p $ORG_MSP/tlscacerts
	cp $ORG_MSP/cacerts/* $ORG_MSP/tlscacerts

	if [ $ADMINCERTS ]; then
		# Copy certificate of org admin
		mkdir -p $ORG_MSP/admincerts
		cp $FABRIC_CA_CLIENT_HOME/msp/signcerts/* $ORG_MSP/admincerts/cert.pem
	fi
}

function main() {

	logr "wait for ca server"
	sleep 20

	mkdir -p FABRIC_CA_CLIENT_HOME

	registerPeerIdentities
	getCACerts
	logr "Finished create certificates"
	logr "Start create TLS"

	logr "Generate server TLS cert and key pair for the peer"
    genClientTLSCert $CORE_PEER_ID $ORG $CORE_PEER_TLS_CERT_FILE $CORE_PEER_TLS_KEY_FILE

	logr "Generate client TLS cert and key pair for the peer"
	genClientTLSCert $CORE_PEER_ID $ORG $CORE_PEER_TLS_CLIENTCERT_FILE $CORE_PEER_TLS_CLIENTKEY_FILE

	logr "Generate client TLS cert and key pair for the peer CLI"
	genClientTLSCert $CORE_PEER_ID $ORG $PEER_CLI_TLS_CERT_FILE $PEER_CLI_TLS_KEY_FILE
    logr "Copy the org's admin cert into some target MSP directory"

    mkdir -p $CORE_PEER_MSPCONFIGPATH/admincerts
    cp $ORG_MSP/admincerts/* $CORE_PEER_MSPCONFIGPATH/admincerts

	logr "Finished create TLS"

	cp /config/core.yaml $FABRIC_CFG_PATH/core.yaml

	logr "Wait for genesis block and bft"
	sleep 80

	logr "Start peer"
	peer node start 2>&1 | tee -a $RUN_SUMPATH
}

main

#!/bin/bash

SDIR=$(dirname "$0")
export RUN_SUMPATH=/data/logs/$CORE_PEER_ID.log
source $SDIR/env.sh

# Wait for setup to complete sucessfully
usage() { echo "Usage: $0 [-c <needs to generate certificates or not>]" 1>&2; exit 1; }
while getopts ":c:" o; do
    case "${o}" in
        c)
            c=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))
if [ -z "${c}" ]; then
    usage
fi

function enrollCAAdmin() {
	mkdir -p $FABRIC_CA_CLIENT_HOME
	rm -rf $FABRIC_CA_CLIENT_HOME/*

	logr "Enrolling with $ENROLLMENT_URL as bootstrap identity ..."
	fabric-ca-client enroll -d -u $ENROLLMENT_URL --enrollment.profile tls
}

# Register any identities associated with a peer
function registerPeerIdentities() {
	enrollCAAdmin

	fabric-ca-client register -d --id.name $CORE_PEER_ID --id.secret $PEER_PASS --id.type peer --id.affiliation $ORG --id.attrs 'admin=true:ecert'

	if [ $ADMINCERTS ]; then
		logr "Registering admin identity with $ADMIN_NAME:$ADMIN_PASS"
		# The admin identity has the "admin" attribute which is added to ECert by default
		fabric-ca-client register -d --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.affiliation $ORG --id.attrs '"hf.Registrar.Roles=user"' --id.attrs '"hf.Registrar.Attributes=*"' --id.attrs 'hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,mycc.init=true:ecert'
		logr "Registering user identity with $USER_NAME:$USER_PASS"
		fabric-ca-client register -d --id.name $USER_NAME --id.secret $USER_PASS --id.affiliation $ORG --id.attrs '"hf.Registrar.Roles=user"'
	fi
}

function getCACerts() {
	logr "Getting CA certificates ..."
	logr "Getting CA certs for organization $ORG and storing in $ORG_MSP"
	mkdir -p $ORG_MSP
	fabric-ca-client getcacert -d -u $ENROLLMENT_URL -M $ORG_MSP

	fabric-ca-client getcacert -d -u $ENROLLMENT_URL -M $ORG_MSP --enrollment.profile tls

	# Copy CA cert
	# mkdir -p $FABRIC_CA_CLIENT_HOME/msp/cacerts
	# cp $ORG_MSP/cacerts/* $FABRIC_CA_CLIENT_HOME/msp/cacerts
	# cp $ORG_MSP/cacerts/* /etc/hyperledger/fabric-ca-server-config/rca.$ORG.bft-cert.pem
	cp $ORG_MSP/tlscacerts/* /etc/hyperledger/fabric-ca-server-config/tls.rca.$ORG.bft-cert.pem
}

function start-peer-and-generate-tls() {

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
	cp $ORG_MSP/cacerts/* $PEER_CERT_DIR/msp/cacerts
	cp $PEER_CERT_DIR/msp/signcerts/* $ORG_MSP/signcerts
	cp $PEER_CERT_DIR/msp/keystore/* $ORG_MSP/keystore
	
	mkdir -p $PEER_CERT_DIR/tls
	cp $PEER_CERT_DIR/msp/signcerts/* $CORE_PEER_TLS_CERT_FILE
	cp $PEER_CERT_DIR/msp/keystore/* $CORE_PEER_TLS_KEY_FILE

	logr "Generate client TLS cert and key pair for the user client"
	genMSPCerts $CORE_PEER_ID $USER_NAME $USER_PASS $ORG $CA_HOST $USER_CERT_DIR/msp
	cp $ORG_MSP/cacerts/* $USER_CERT_DIR/msp/cacerts

	cp $USER_CERT_DIR/msp/signcerts/* $CORE_PEER_TLS_CLIENTCERT_FILE
	cp $USER_CERT_DIR/msp/keystore/* $CORE_PEER_TLS_CLIENTKEY_FILE

	if [ $ADMINCERTS ]; then
		logr "Generate client TLS cert and key pair for the admin of org"
		genMSPCerts $CORE_PEER_ID $ADMIN_NAME $ADMIN_PASS $ORG $CA_HOST $ADMIN_CERT_DIR/msp
		cp $ORG_MSP/cacerts/* $ADMIN_CERT_DIR/msp/cacerts

		mkdir -p $ADMIN_CERT_DIR/tls
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

	start-peer-only
}

function start-peer-only() {
	cp /config/core.yaml $FABRIC_CFG_PATH/core.yaml

	logr "Wait for genesis block and bft"
	sleep 80

	logr "Start peer"
	peer node start 2>&1 | tee -a $RUN_SUMPATH 
}

if [ $c -eq 1 ]; then
	start-peer-and-generate-tls
else
	start-peer-only
fi
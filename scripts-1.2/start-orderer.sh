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

	fabric-ca-client register -d --id.name $CORE_PEER_ID --id.secret $ORDERER_PASS --id.type orderer

	logr "Registering admin identity with $ENROLLMENT_URL"
	# The admin identity has the "admin" attribute which is added to ECert by default
	fabric-ca-client register -d --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.attrs "admin=true:ecert"
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

	registerOrdererIdentities
	getCACerts
	logr "Finished create certificates"
	logr "Start create TLS"

	logr "Enroll to get orderer's TLS cert (using the tls profile)"
    genClientTLSCert $CORE_PEER_ID $ORG $ORDERER_GENERAL_TLS_CERTIFICATE $ORDERER_GENERAL_TLS_PRIVATEKEY

	logr "Enroll again to get the orderer's enrollment certificate (default profile)"
    fabric-ca-client enroll -d -u $ENROLLMENT_URL -M $ORDERER_GENERAL_LOCALMSPDIR

    mkdir -p $ORDERER_GENERAL_LOCALMSPDIR/tlscacerts
	cp $ORDERER_GENERAL_LOCALMSPDIR/cacerts/* $ORDERER_GENERAL_LOCALMSPDIR/tlscacerts

    logr "Copy the org's admin cert into some target MSP directory"

    mkdir -p $ORDERER_GENERAL_LOCALMSPDIR/admincerts
    cp $ORG_MSP/admincerts/* $ORDERER_GENERAL_LOCALMSPDIR/admincerts

	logr "Finished create TLS"

	cp /config/orderer.yaml $FABRIC_CFG_PATH/orderer.yaml

	logr "wait for genesis block and replicas"
	sleep 50

    logr "Start frontend"
	cd $GOPATH/src/github.com/hyperledger/fabric-orderingservice
	rm -rf config/currentView
	cp /config/hosts.config config/hosts.config
	cp /config/node.config config/node.config
	./startFrontend.sh 1000 10 9999 2>&1 | tee -a $RUN_FRONTEND &

	logr "Wait for genesis block and bft"
	sleep 20

	logr "Start orderer"
	orderer start 2>&1 | tee -a $RUN_SUMPATH
}

main
#!/bin/bash

FABRIC_ORGS="org0 org1 org2"

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

	logr "Enroll to get peer's TLS cert"

	mkdir -p $MSP_DIR

	fabric-ca-client enroll -d --enrollment.profile tls -u https://$NAME:$PASSWORD@$CA_HOST_NAME:7054 -M $MSP_DIR --csr.hosts $HOST_NAME --csr.names C=US,ST="California",O=${ORG},OU=COP

	# Copy CA certs
	mkdir $MSP_DIR/tlscacerts
	mkdir $MSP_DIR/cacerts
    cp $ORG_MSP/cacerts/* $MSP_DIR/tlscacerts
	cp $ORG_MSP/cacerts/* $MSP_DIR/cacerts
}

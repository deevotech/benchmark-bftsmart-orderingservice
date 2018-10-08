#!/bin/bash

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

function genClientTLSCert() {
	if [ $# -ne 4 ]; then
		echo "Usage: genClientTLSCert <host name> <org> <cert file> <key file>: $*"
		exit 1
	fi

	HOST_NAME=$1
	ORG=$2
	CERT_FILE=$3
	KEY_FILE=$4

	logr "Enroll to get peer's TLS cert"

	rm -rf /tmp/tls
	mkdir -p /tmp/tls

	fabric-ca-client enroll -d --enrollment.profile tls -u $ENROLLMENT_URL -M /tmp/tls --csr.hosts $HOST_NAME --csr.names C=US,ST="California",O=${ORG},OU: COP

	cp /tmp/tls/signcerts/* $CERT_FILE
	cp /tmp/tls/keystore/* $KEY_FILE
	rm -rf /tmp/tls
}

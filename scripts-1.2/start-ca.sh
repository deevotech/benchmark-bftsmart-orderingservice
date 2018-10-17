#!/bin/bash

SDIR=$(dirname "$0")
source $SDIR/env.sh

export RUN_SUMPATH=/data/logs/ca-${ORG}.log

mkdir -p /etc/hyperledger/fabric-ca-server-config
rm -rf /etc/hyperledger/fabric-ca-server-config/*

logr "Init CA server"

fabric-ca-server init -b $BOOTSTRAP_USER_PASS
# cp $FABRIC_CA_SERVER_HOME/ca-cert.pem $TARGET_CERTFILE
# cp $FABRIC_CA_SERVER_HOME/ca-cert.pem $FABRIC_CA_SERVER_TLS_KEYFILE

# Add the custom orgs
for o in $FABRIC_ORGS; do
	aff=$aff"\n   $o: []"
done
logr $aff
perl -0777 -i.original -pe "s/affiliations:\n   org1:\n      - department1\n      - department2\n   org2:\n      - department1/affiliations:$aff/" $FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml
sed -i "s/ST: \"North Carolina\"/ST: \"California\"/g" \
	$FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml
sed -i "s/OU: Fabric/OU: COP/g" \
	$FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml
sed -i "s/O: Hyperledger/O: $ORG/g" \
	$FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml

cp $FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml /etc/hyperledger/fabric-ca-server-config/fabric-ca-server-config.yaml

fabric-ca-server init -b $BOOTSTRAP_USER_PASS
cp $FABRIC_CA_SERVER_HOME/ca-cert.pem $FABRIC_CA_SERVER_TLS_KEYFILE

logr "Start CA server"

fabric-ca-server start --ca.certfile $FABRIC_CA_SERVER_TLS_CERTFILE --ca.keyfile $FABRIC_CA_SERVER_TLS_KEYFILE -b $BOOTSTRAP_USER_PASS -d 2>&1 | tee -a  $RUN_SUMPATH
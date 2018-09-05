#!/bin/bash

set -e
source $(dirname "$0")/env.sh
while [ ! -f /data/logs/all.ordering.node.success ] ; do
 sleep 2
done
cp /data/genesis.block /etc/bftsmart-orderer/config/genesisblock
cp /data/key.pem /etc/bftsmart-orderer/config/key.pem
cp /data/peer.pem /etc/bftsmart-orderer/config/peer.pem
cp /data/key.pem /etc/bftsmart-orderer/config/key.pem
cp /data/node.config /etc/bftsmart-orderer/config/node.config

cp /data/peer.pem /go/src/github.com/hyperledger/fabric-orderingservice/config/peer.pem
cp /data/peer.pem /go/src/github.com/hyperledger/fabric-orderingservice/config/peer.pem
cp /data/node.config /go/src/github.com/hyperledger/fabric-orderingservice/config/node.config

cd /go/src/github.com/hyperledger/fabric-orderingservice;
if [ -f ./config/currentView ]; then
rm -f ./config/currentView
fi
# start frontend
echo $JAVA_HOME
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64 && ./startFrontend.sh 1000 10 9999 > /data/logs/frontend-0.success 2>&1 &
sleep 5
#dowait "genesis block to be created" 60 $SETUP_LOGFILE $ORDERER_GENERAL_GENESISFILE
while [ ! -f /data/logs/frontend-0.success ] ; do
 sleep 2
done
cp /config/core-orderer.yaml /etc/hyperledger/fabric/core.yaml
cp /data/genesis.block /etc/hyperledger/fabric/genesis.block
cp /config/orderer.yaml /etc/hyperledger/fabric/orderer.yaml
fabric-ca-client enroll -d --enrollment.profile tls -u $ENROLLMENT_URL -M /tmp/tls --csr.hosts $ORDERER_HOST

# Copy the TLS key and cert to the appropriate place
TLSDIR=$ORDERER_HOME/tls
mkdir -p $TLSDIR
cp /tmp/tls/keystore/* $ORDERER_GENERAL_TLS_PRIVATEKEY
cp /tmp/tls/signcerts/* $ORDERER_GENERAL_TLS_CERTIFICATE
rm -rf /tmp/tls

# Enroll again to get the orderer's enrollment certificate (default profile)
fabric-ca-client enroll -d -u $ENROLLMENT_URL -M $ORDERER_GENERAL_LOCALMSPDIR

# Finish setting up the local MSP for the orderer
finishMSPSetup $ORDERER_GENERAL_LOCALMSPDIR
copyAdminCert $ORDERER_GENERAL_LOCALMSPDIR

# Wait for the genesis block to be created
dowait "genesis block to be created" 60 $SETUP_LOGFILE $ORDERER_GENERAL_GENESISFILE
# Start the orderer
env | grep ORDERER > /data/orderer.config
env | grep ORDERER
if [ ! -d /etc/hyperledger/orderer/msp/admincerts ] ; then
mkdir /etc/hyperledger/orderer/msp/admincerts
cp /data/orgs/org0/msp/admincerts/cert.pem /etc/hyperledger/orderer/msp/admincerts/
fi
touch /data/logs/orderer.successful
orderer

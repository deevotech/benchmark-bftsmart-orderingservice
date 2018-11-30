SDIR=$(dirname "$0")
source $SDIR/env.sh

export RUN_SUMPATH=/data/logs_2/run-marbles.log

export ROOT_CRYPTO_DIR=/etc/hyperledger/fabric/crypto-config
export ORDERER_ORG=org0
export ORDERER_HOST=orderer0.${ORDERER_ORG}.deevo.io
export ORDERER_TLS_CA=$ROOT_CRYPTO_DIR/orgs/${ORDERER_ORG}/ca/rca.${ORDERER_ORG}.deevo.io-cert.pem
export ORDERER_PORT_ARGS="-o $ORDERER_HOST:7050 --tls --cafile $ORDERER_TLS_CA --clientauth"
NUM_PEERS=1

# Convert PEER_ORGS to an array named PORGS
IFS=', ' read -r -a PORGS <<<"$PEER_ORGS"

# initOrgVars <ORG>
function initOrgVars() {
	if [ $# -ne 1 ]; then
		echo "Usage: initOrgVars <ORG>"
		exit 1
	fi
	ORG=$1
	ROOT_CA_HOST=rca.${ORG}.deevo.io
	ROOT_CA_NAME=rca.${ORG}.deevo.io

	# Root CA admin identity
	ROOT_CA_ADMIN_USER_PASS=rca-admin:rca-adminpw

	ROOT_CA_CERTFILE=$ROOT_CRYPTO_DIR/orgs/${ORG}/ca/rca.${ORG}.deevo.io-cert.pem

	mkdir -p $ARTIFACT_DIR/${ORG}

	ANCHOR_TX_FILE=$ARTIFACT_DIR/${ORG}/anchors.tx
	ORG_MSP_ID=${ORG}MSP
	ORG_MSP_DIR=$ROOT_CRYPTO_DIR/orgs/${ORG}/msp
	ORG_ADMIN_CERT=${ORG_MSP_DIR}/admincerts/cert.pem
	# ORG_ADMIN_HOME=${DATA}/orgs/$ORG/admin

	CA_NAME=$ROOT_CA_NAME
	CA_HOST=$ROOT_CA_HOST
	CA_CHAINFILE=$ROOT_CA_CERTFILE
	CA_ADMIN_USER_PASS=$ROOT_CA_ADMIN_USER_PASS
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
	PEER_HOST=peer${NUM}.${ORG}.deevo.io
	PEER_NAME=peer${NUM}.${ORG}.deevo.io

	cp /config/core.yaml $FABRIC_CFG_PATH/core.yaml

	export FABRIC_CA_CLIENT=/etc/ca-client
	mkdir -p $FABRIC_CA_CLIENT

	export CORE_PEER_ID=$PEER_HOST
	export CORE_PEER_ADDRESS=$PEER_HOST:7051
	export CORE_PEER_LOCALMSPID=$ORG_MSP_ID
	export CORE_PEER_MSPCONFIGPATH=$ROOT_CRYPTO_DIR/orgs/$ORG/$PEER_NAME/msp
	export CORE_PEER_TLS_CLIENTCERT_FILE=$ROOT_CRYPTO_DIR/orgs/$ORG/$PEER_NAME/tls/server.crt
	export CORE_PEER_TLS_CLIENTKEY_FILE=$ROOT_CRYPTO_DIR/orgs/$ORG/$PEER_NAME/tls/server.key
	# export CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
	# the following setting starts chaincode containers on the same
	# bridge network as the peers
	# https://docs.docker.com/compose/networking/
	#export CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=${COMPOSE_PROJECT_NAME}_${NETWORK}
	# export CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=net_${NETWORK}
	# export CORE_LOGGING_LEVEL=ERROR
	export CORE_LOGGING_LEVEL=DEBUG
	export CORE_PEER_TLS_ENABLED=true
	export CORE_PEER_TLS_CLIENTAUTHREQUIRED=true
	export CORE_PEER_TLS_ROOTCERT_FILE=$CA_CHAINFILE

	ADMIN_TLS_DIR=$ROOT_CRYPTO_DIR/orgs/$ORG/admin/tls

	export CORE_PEER_TLS_CLIENTCERT_FILE=$ADMIN_TLS_DIR/client.crt
	export CORE_PEER_TLS_CLIENTKEY_FILE=$ADMIN_TLS_DIR/client.key

	export CORE_PEER_PROFILE_ENABLED=true
	# gossip variables
	export CORE_PEER_GOSSIP_USELEADERELECTION=true
	export CORE_PEER_GOSSIP_ORGLEADER=false
	export CORE_PEER_GOSSIP_EXTERNALENDPOINT=$PEER_HOST:7051
	# if [ $NUM -gt 1 ]; then
	# 	# Point the non-anchor peers to the anchor peer, which is always the 1st peer
	# 	export CORE_PEER_GOSSIP_BOOTSTRAP=peer0-${ORG}:7051
	# fi
	export ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"
}

cp /config/configtx.yaml /etc/hyperledger/fabric/configtx.yaml
CHANNEL_ARTIFACTS_DIR=/etc/hyperledger/channel-artifacts
GENESIS_BLOCK_FILE=$CHANNEL_ARTIFACTS_DIR/genesis.block
CHAINCODE_NAME=marble-cc
CHAINCODE_VERSION=1.0

logr "install chaincode on peer0"
for ORG in $PEER_ORGS; do
	initPeerVars $ORG 1

	logr "Install chaincode for $PEER_HOST ..."
	peer chaincode install -n $CHAINCODE_NAME -v $CHAINCODE_VERSION -p github.com/hyperledger/fabric-samples/chaincode/marbles02/go 2>&1 | tee -a /data/logs_2/${PEER_HOST}_install.log &

	sleep 1
done

sleep 30

logr "instantiate chaincode on ${PORGS[0]} peer0"
POLICY="OR('org1MSP.member','org2MSP.member')"
initPeerVars ${PORGS[0]} 1

peer chaincode instantiate -C $CHANNEL_ID -n ${CHAINCODE_NAME} -v $CHAINCODE_VERSION -P ${POLICY} -c '{"Args":["init"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a /data/logs_2/instantiate.log &

sleep 20

peer chaincode list --instantiated -C $CHANNEL_ID 2>&1 | tee -a /data/logs_2/${PEER_HOST}_installed.log &
sleep 10

logr "query chaincode"

initPeerVars ${PORGS[1]} 1
peer chaincode invoke -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["initMarble","marble1","blue","35","tom"]}' $ORDERER_CONN_ARGS
sleep 3
peer chaincode invoke -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["initMarble","marble2","red","50","tom"]}' $ORDERER_CONN_ARGS
sleep 3
peer chaincode invoke -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["initMarble","marble3","blue","70","tom"]}' $ORDERER_CONN_ARGS
sleep 3
peer chaincode invoke -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["transferMarble","marble2","jerry"]}' $ORDERER_CONN_ARGS
sleep 3
peer chaincode invoke -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["transferMarblesBasedOnColor","blue","jerry"]}' $ORDERER_CONN_ARGS
sleep 3
peer chaincode invoke -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["delete","marble1"]}' $ORDERER_CONN_ARGS
sleep 3
peer chaincode invoke -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["readMarble","marble1"]}' $ORDERER_CONN_ARGS
sleep 3
peer chaincode invoke -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["getMarblesByRange","marble1","marble3"]}' $ORDERER_CONN_ARGS
sleep 3
peer chaincode invoke -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["getHistoryForMarble","marble1"]}' $ORDERER_CONN_ARGS
sleep 3
#Rich Query (Only supported if CouchDB is used as state database):

# peer chaincode invoke -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["queryMarblesByOwner","tom"]}' $ORDERER_CONN_ARGS
# sleep 3
# peer chaincode invoke -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["queryMarbles","{\"selector\":{\"owner\":\"tom\"}}"]}' $ORDERER_CONN_ARGS

logr "FINISHED"

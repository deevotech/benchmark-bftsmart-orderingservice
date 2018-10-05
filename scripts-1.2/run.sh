SDIR=$(dirname "$0")
source $SDIR/env.sh

export RUN_SUMPATH=/data/logs/run.log

export ROOT_CRYPTO_DIR=/etc/hyperledger/fabric/crypto-config
export ORDERER_ORG=org0
export ORDERER_HOST=orderer1.${ORDERER_ORG}.bft
export ORDERER_TLS_CA=$ROOT_CRYPTO_DIR/orgs/${ORDERER_ORG}/ca/rca.${ORDERER_ORG}.bft-cert.pem
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
	ROOT_CA_HOST=rca.${ORG}.bft
	ROOT_CA_NAME=rca.${ORG}.bft

	# Root CA admin identity
	ROOT_CA_ADMIN_USER_PASS=rca-admin:rca-adminpw

	ROOT_CA_CERTFILE=$ROOT_CRYPTO_DIR/orgs/${ORG}/ca/rca.${ORG}.bft-cert.pem

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
	PEER_HOST=peer${NUM}.${ORG}.bft
	PEER_NAME=peer${NUM}.${ORG}.bft

	cp /config/core.yaml $FABRIC_CFG_PATH/core.yaml

	export FABRIC_CA_CLIENT=/etc/ca-client
	mkdir -p $FABRIC_CA_CLIENT

	export CORE_PEER_ID=$PEER_HOST
	export CORE_PEER_ADDRESS=$PEER_HOST:7051
	export CORE_PEER_LOCALMSPID=$ORG_MSP_ID
	export CORE_PEER_MSPCONFIGPATH=$ROOT_CRYPTO_DIR/orgs/$ORG/$PEER_NAME/msp
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

	TLS_DIR=$ROOT_CRYPTO_DIR/orgs/$1/$PEER_NAME/tls

	export CORE_PEER_TLS_CLIENTCERT_FILE=$TLS_DIR/cli-client.crt
	export CORE_PEER_TLS_CLIENTKEY_FILE=$TLS_DIR/cli-client.key

	export CORE_PEER_PROFILE_ENABLED=true
	# gossip variables
	export CORE_PEER_GOSSIP_USELEADERELECTION=true
	export CORE_PEER_GOSSIP_ORGLEADER=false
	export CORE_PEER_GOSSIP_EXTERNALENDPOINT=$PEER_HOST:7051
	# if [ $NUM -gt 1 ]; then
	# 	# Point the non-anchor peers to the anchor peer, which is always the 1st peer
	# 	export CORE_PEER_GOSSIP_BOOTSTRAP=peer1-${ORG}:7051
	# fi
	export ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"
}

logr "wait for peers"
sleep 40

cp /config/configtx.yaml /etc/hyperledger/fabric/configtx.yaml
CHANNEL_ARTIFACTS_DIR=/etc/hyperledger/channel-artifacts
GENESIS_BLOCK_FILE=$CHANNEL_ARTIFACTS_DIR/genesis.block
CHANNEL_TX_FILE=$CHANNEL_ARTIFACTS_DIR/$CHANNEL_ID.tx
CHANNEL_BLOCK_FILE=$CHANNEL_ARTIFACTS_DIR/$CHANNEL_ID.block
CHAINCODE_NAME=mycc1

logr "create genesis block"

configtxgen -profile SampleSingleMSPBFTsmart -outputBlock $GENESIS_BLOCK_FILE
if [ "$?" -ne 0 ]; then
	fatal "Failed to generate orderer genesis block"
fi
logr "success"

logr "wait for bft"
sleep 80

logr "create channel tx"

configtxgen -profile SampleSingleMSPChannel -outputCreateChannelTx $CHANNEL_TX_FILE -channelID $CHANNEL_ID
if [ "$?" -ne 0 ]; then
	fatal "Failed to generate channel configuration transaction"
fi

for ORG in $PEER_ORGS; do
	initOrgVars $ORG
	logr "Generating anchor peer update transaction for $ORG at $ANCHOR_TX_FILE"
	configtxgen -profile SampleSingleMSPChannel -outputAnchorPeersUpdate $ANCHOR_TX_FILE \
		-channelID $CHANNEL_ID -asOrg $ORG
	if [ "$?" -ne 0 ]; then
		fatal "Failed to generate anchor peer update for $ORG"
	fi
	LS=$(ls $ARTIFACT_DIR/${ORG})
	logr "anchor peer update transaction $LS"
done

logr "Creating channel '$CHANNEL_ID' on $ORDERER_HOST from ${PORGS[0]} ..."
initPeerVars ${PORGS[0]} 1

peer channel create --logging-level=DEBUG -c $CHANNEL_ID -f $CHANNEL_TX_FILE $ORDERER_CONN_ARGS --outputBlock $CHANNEL_BLOCK_FILE

logr "ALL peers join the channel"
for ORG in $PEER_ORGS; do
	COUNT=1
	while [[ "$COUNT" -le $NUM_PEERS ]]; do
		initPeerVars $ORG $COUNT
		C=1
		MAX_RETRY=10
		while true; do
			logr "Peer $PEER_HOST is attempting to join channel '$CHANNEL_ID' (attempt #${C}) ..."
			peer channel join -b $CHANNEL_BLOCK_FILE
			if [ $? -eq 0 ]; then
				logr "Peer $PEER_HOST successfully joined channel '$CHANNEL_ID'"
				break
			fi
			if [ $C -gt $MAX_RETRY ]; then
				logr "Peer $PEER_HOST failed to join channel '$CHANNEL_ID' in $MAX_RETRY retries"
			fi
			C=$((C + 1))
			sleep 2
		done
		COUNT=$((COUNT + 1))
	done
done
logr "ALL peers join the channel DONE"
sleep 5
logr "Update the anchor peers"
for ORG in $PEER_ORGS; do
	initPeerVars $ORG 1

	ANCHOR_TX_FILE=$CHANNEL_ARTIFACTS_DIR/$ORG/anchors.tx
	echo $ORDERER_CONN_ARGS
	peer channel update -c $CHANNEL_ID -f $ANCHOR_TX_FILE $ORDERER_CONN_ARGS
	sleep 2
done
logr "Update the anchor peers: DONE"

logr "install chaincode on peer1"
for ORG in $PEER_ORGS; do
	initPeerVars $ORG 1

	logr "Install chaincode for $PEER_HOST ..."
	peer chaincode install -n $CHAINCODE_NAME -v 1.0 -p github.com/hyperledger/fabric-samples/chaincode/chaincode_example02/go 2>&1 | tee -a /data/logs/${PEER_HOST}_install.log &

	sleep 10
done

logr "instantiate chaincode on ${PORGS[0]} peer1"
initPeerVars ${PORGS[0]} 1

POLICY="OR ('org1MSP.member', 'org2MSP.member')"
peer chaincode instantiate -C $CHANNEL_ID -n ${CHAINCODE_NAME} -v 1.0 -P "$POLICY" -c '{"Args":["init","a","100","b","200"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a /data/logs/instantiate.log &

sleep 10

peer chaincode list --instantiated -C $CHANNEL_ID 2>&1 | tee -a /data/logs/${PEER_HOST}_installed.log &
sleep 5

# logr "query chaincode"
# logr "query a"
# peer chaincode query -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["query","a"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a /data/logs/query1.log &

# sleep 10

# logr "invoke a -> b"
# peer chaincode invoke -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["invoke","a","b","10"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a /data/logs/query2.log &

# sleep 10
# logr "query a (2)"
# peer chaincode query -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["query","a"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a /data/logs/query3.log &

logr "FINISHED"

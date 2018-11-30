SDIR=$(dirname "$0")
source $SDIR/env.sh
export RUN_SUMPATH=/data/logs/network/run.log

declare -A NODES='('${NODE_COUNT}')'
declare -a PEER_ORGS_ARRAY='('${PEER_ORGS[*]}')'

cp -f /config/configtx.yaml $FABRIC_CFG_PATH/configtx.yaml
cp -f /config/core.yaml $FABRIC_CFG_PATH/core.yaml
# CHANNEL_ARTIFACTS_DIR=/etc/hyperledger/channel-artifacts
# GENESIS_BLOCK_FILE=$CHANNEL_ARTIFACTS_DIR/genesis.block
CHANNEL_TX_FILE=$ARTIFACT_DIR/$CHANNEL_ID.tx
CHANNEL_BLOCK_FILE=$ARTIFACT_DIR/$CHANNEL_ID.block
CHAINCODE_NAME=mycc1

logr "create genesis block"

configtxgen -outputBlock $GENESIS_BLOCK_FILE -profile SampleSingleMSPBFTsmart -channelID orderer-system-channel
if [ "$?" -ne 0 ]; then
	fatal "Failed to generate orderer genesis block"
fi
logr "success"

configtxgen -inspectBlock $GENESIS_BLOCK_FILE > /data/network/genesis.json &
sleep 1

logr "create channel tx"

configtxgen -outputCreateChannelTx $CHANNEL_TX_FILE -profile SampleSingleMSPChannel -channelID $CHANNEL_ID
if [ "$?" -ne 0 ]; then
	fatal "Failed to generate channel configuration transaction"
fi

configtxgen -inspectChannelCreateTx $CHANNEL_TX_FILE > /data/network/channel-config.json &
sleep 1

logr "wait for bft"
sleep 60

for ORG in ${PEER_ORGS[*]}; do
	initOrgVars $ORG
	cleanOrCreateDirectory $ARTIFACT_DIR/${ORG}
	logr "Generating anchor peer update transaction for $ORG at $ANCHOR_TX_FILE"
	configtxgen -profile SampleSingleMSPChannel -outputAnchorPeersUpdate $ANCHOR_TX_FILE -channelID $CHANNEL_ID -asOrg $ORG
	if [ "$?" -ne 0 ]; then
		fatal "Failed to generate anchor peer update for $ORG"
	fi
	LS=$(ls $ARTIFACT_DIR/${ORG})
	logr "anchor peer update transaction $LS"
done

logr "Creating channel '$CHANNEL_ID' on $ORDERER_HOST from ${PEER_ORGS_ARRAY[0]} ..."
initPeerVars ${PEER_ORGS_ARRAY[0]} 0
initPeerAdminVars
logr "orderer connection $ORDERER_CONN_ARGS"
peer channel create --logging-level=DEBUG -c $CHANNEL_ID -f $CHANNEL_TX_FILE $ORDERER_CONN_ARGS --outputBlock $CHANNEL_BLOCK_FILE 2>&1 | tee -a /data/logs/network/create_channel.log &

sleep 10

logr "ALL peers join the channel"
for ORG in ${PEER_ORGS[*]}; do
	COUNT=0
	while [ $COUNT -lt ${NODES[$ORG]} ]; do
		initPeerVars $ORG $COUNT
		initPeerAdminVars
		C=1
		MAX_RETRY=1
		while true; do
			logr "Peer $PEER_HOST is attempting to join channel '$CHANNEL_ID' (attempt #${C}) ..."
			logr "orderer connection $ORDERER_CONN_ARGS"
			peer channel join -b $CHANNEL_BLOCK_FILE
			if [ $? -eq 0 ]; then
				logr "Peer $PEER_HOST successfully joined channel '$CHANNEL_ID'"
				break
			fi
			if [ $C -gt $MAX_RETRY ]; then
				logr "Peer $PEER_HOST failed to join channel '$CHANNEL_ID' in $MAX_RETRY retries"
				exit 0
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
for ORG in ${PEER_ORGS[*]}; do
	initPeerVars $ORG 0
	initPeerAdminVars

	ANCHOR_TX_FILE=$ARTIFACTS_DIR/$ORG/anchors.tx
	echo $ORDERER_CONN_ARGS
	peer channel update -c $CHANNEL_ID -f $ANCHOR_TX_FILE $ORDERER_CONN_ARGS
	sleep 2
done
logr "Update the anchor peers: DONE"

initPeerVars org1 0
peer channel getinfo -c $CHANNEL_ID $ORDERER_CONN_ARGS 2>&1 | tee -a /data/logs/network/channel.log &
sleep 1

logr "install chaincode on peer0"
for ORG in ${PEER_ORGS[*]}; do
	initPeerVars $ORG 0
	initPeerAdminVars

	logr "Install chaincode for $PEER_HOST ..."
	peer chaincode install -n $CHAINCODE_NAME -v 1.0 -p github.com/hyperledger/fabric-samples/chaincode/chaincode_example02/go 2>&1 | tee -a /data/logs/network/${PEER_HOST}_install.log &

	sleep 1
done

sleep 30

logr "instantiate chaincode on ${PEER_ORGS_ARRAY[0]} peer0"
POLICY="OR('org1MSP.member','org2MSP.member')"
initPeerVars ${PEER_ORGS_ARRAY[0]} 0
initPeerAdminVars

peer chaincode instantiate -C $CHANNEL_ID -n ${CHAINCODE_NAME} -v 1.0 -P ${POLICY} -c '{"Args":["init","a","100","b","200"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a /data/logs/network/instantiate.log &

sleep 20

peer chaincode list --instantiated -C $CHANNEL_ID 2>&1 | tee -a /data/logs/network/${PEER_HOST}_installed.log &
sleep 10

logr "query chaincode"
logr "query a"
peer chaincode query -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["query","a"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a /data/logs/network/query1.log &

sleep 10

initPeerVars ${PEER_ORGS_ARRAY[1]} 0
initPeerAdminVars

logr "invoke a -> b"
peer chaincode invoke -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["invoke","a","b","10"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a /data/logs/network/query2.log &

sleep 10
logr "query a (2)"
peer chaincode query -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["query","a"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a /data/logs/network/query3.log &

sleep 10

logr "get newest block"
peer channel fetch newest /etc/hyperledger/channel-artifacts/block.txt -c $CHANNEL_ID $ORDERER_CONN_ARGS 2>&1 | tee -a /data/logs/network/getblock.log &

sleep 10
logr "FINISHED"

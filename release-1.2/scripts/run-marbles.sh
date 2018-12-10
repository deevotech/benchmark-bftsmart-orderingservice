SDIR=$(dirname "$0")
source $SDIR/env.sh

LOG_DIR=/data/logs/marble
export RUN_SUMPATH=$LOG_DIR/run-marbles.log

declare -A NODES='('${NODE_COUNT}')'
declare -a PEER_ORGS_ARRAY='('${PEER_ORGS[*]}')'

cp -f /config/configtx-aimthai.yaml $FABRIC_CFG_PATH/configtx.yaml
cp -f /config/core.yaml $FABRIC_CFG_PATH/core.yaml

CHANNEL_TX_FILE=$ARTIFACT_DIR/$CHANNEL_ID.tx
CHANNEL_BLOCK_FILE=$ARTIFACT_DIR/$CHANNEL_ID.block
CHAINCODE_NAME=marble-cc
CHAINCODE_VERSION=1.0

logr "create channel tx"

configtxgen -outputCreateChannelTx $CHANNEL_TX_FILE -profile AimThaiChannel -channelID $CHANNEL_ID
if [ "$?" -ne 0 ]; then
	fatal "Failed to generate channel configuration transaction"
fi

configtxgen -inspectChannelCreateTx $CHANNEL_TX_FILE > $LOG_DIR/channel-config.json &
sleep 1

for ORG in ${PEER_ORGS[*]}; do
	initOrgVars $ORG
	cleanOrCreateDirectory $ARTIFACT_DIR/marble/${ORG}
	ANCHOR_TX_FILE=$ARTIFACT_DIR/marble/${ORG}/anchor.tx

	logr "Generating anchor peer update transaction for $ORG at $ANCHOR_TX_FILE"
	configtxgen -profile AimThaiChannel -outputAnchorPeersUpdate $ANCHOR_TX_FILE -channelID $CHANNEL_ID -asOrg $ORG
	if [ "$?" -ne 0 ]; then
		fatal "Failed to generate anchor peer update for $ORG"
	fi
	LS=$(ls $ARTIFACT_DIR/marble/${ORG})
	logr "anchor peer update transaction $LS"
done

logr "Creating channel '$CHANNEL_ID' on $ORDERER_HOST from ${PEER_ORGS_ARRAY[0]} ..."
initPeerVars ${PEER_ORGS_ARRAY[0]} 0
initPeerAdminCLI
logr "orderer connection $ORDERER_CONN_ARGS"
peer channel create --logging-level=DEBUG -c $CHANNEL_ID -f $CHANNEL_TX_FILE $ORDERER_CONN_ARGS --outputBlock $CHANNEL_BLOCK_FILE 2>&1 | tee -a $LOG_DIR/create_channel.log &

sleep 10

logr "ALL peers join the channel"
for ORG in ${PEER_ORGS[*]}; do
	COUNT=0
	while [ $COUNT -lt ${NODES[$ORG]} ]; do
		initPeerVars $ORG $COUNT
		initPeerAdminCLI
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
	initPeerAdminCLI

	ANCHOR_TX_FILE=$ARTIFACT_DIR/marble/${ORG}/anchor.tx
	echo $ORDERER_CONN_ARGS
	peer channel update -c $CHANNEL_ID -f $ANCHOR_TX_FILE $ORDERER_CONN_ARGS
	sleep 2
done
logr "Update the anchor peers: DONE"

initPeerVars org1 0
peer channel getinfo -c $CHANNEL_ID $ORDERER_CONN_ARGS 2>&1 | tee -a $LOG_DIR/channel.log &
sleep 1

logr "install chaincode on peer0"
for ORG in ${PEER_ORGS[*]}; do
	initPeerVars $ORG 0
	initPeerAdminCLI

	logr "Install chaincode for $PEER_HOST ..."
	peer chaincode install -n $CHAINCODE_NAME -v $CHAINCODE_VERSION -p github.com/hyperledger/fabric-samples/chaincode/marbles02/go 2>&1 | tee -a $LOG_DIR/${PEER_HOST}_install.log &

	sleep 1
done

sleep 30

logr "instantiate chaincode on ${PEER_ORGS_ARRAY[0]} peer0"
POLICY="AND('org1MSP.member','org2MSP.member')"
initPeerVars ${PEER_ORGS_ARRAY[0]} 0
initPeerAdminCLI

peer chaincode instantiate -C $CHANNEL_ID -n ${CHAINCODE_NAME} -v $CHAINCODE_VERSION -P ${POLICY} -c '{"Args":["init"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a $LOG_DIR/instantiate.log &

sleep 20

peer chaincode list --instantiated -C $CHANNEL_ID 2>&1 | tee -a $LOG_DIR/${PEER_HOST}_installed.log &
sleep 10

logr "query chaincode"

initPeerVars ${PEER_ORGS_ARRAY[0]} 0
initPeerUserCLI

ENDORSER_PEER="--peerAddresses peer0.org1.deevo.io:7051 --tlsRootCertFiles $CRYPTO_DIR/cacerts/org1/rca.org1.deevo.io-cert.pem --peerAddresses peer0.org2.deevo.io:7051 --tlsRootCertFiles $CRYPTO_DIR/cacerts/org2/rca.org2.deevo.io-cert.pem"

logr $ENDORSER_PEER

logr "initMarble marble1"
peer chaincode invoke $ENDORSER_PEER -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["initMarble","marble1","blue","35","tom"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a $LOG_DIR/query1.log &
sleep 30
logr "readMarble marble1"
peer chaincode query -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["readMarble","marble1"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a $LOG_DIR/query1_1.log &
sleep 3
logr "initMarble marble2"
peer chaincode invoke $ENDORSER_PEER -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["initMarble","marble2","red","50","tom"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a $LOG_DIR/query2.log &
sleep 3
logr "initMarble marble3"
peer chaincode invoke $ENDORSER_PEER -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["initMarble","marble3","blue","70","tom"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a $LOG_DIR/query3.log &
sleep 3
logr "transferMarble marble2"
peer chaincode invoke $ENDORSER_PEER -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["transferMarble","marble2","jerry"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a $LOG_DIR/query4.log &
sleep 3
logr "transferMarblesBasedOnColor blue"
peer chaincode invoke $ENDORSER_PEER -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["transferMarblesBasedOnColor","blue","jerry"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a $LOG_DIR/query5.log &
sleep 3
logr "readMarble marble2"
peer chaincode query -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["readMarble","marble1"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a $LOG_DIR/query5_1.log &
sleep 3
logr "delete marble1"
peer chaincode invoke $ENDORSER_PEER -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["delete","marble1"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a $LOG_DIR/query6.log &
sleep 3
logr "readMarble marble1"
peer chaincode query -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["readMarble","marble1"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a $LOG_DIR/query7.log &
sleep 3
logr "getMarblesByRange marble1 mable3"
peer chaincode query -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["getMarblesByRange","marble1","marble3"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a $LOG_DIR/query8.log &
sleep 3
logr "getHistoryForMarble marble1"
peer chaincode query -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["getHistoryForMarble","marble1"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a $LOG_DIR/query9.log &
sleep 3

logr "FINISHED"

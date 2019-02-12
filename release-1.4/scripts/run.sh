SDIR=$(dirname "$0")
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

export RUN_SUMPATH=/data/logs/run.log

NUM_PEERS=1

# Convert PEER_ORGS to an array named PORGS
IFS=', ' read -r -a PORGS <<<"$PEER_ORGS"

logr "wait for peers"
if [ $c -eq 1 ]; then
	sleep 36
else
	sleep 2
fi

cp /config/configtx.yaml /etc/hyperledger/fabric/configtx.yaml
CHANNEL_ARTIFACTS_DIR=/etc/hyperledger/channel-artifacts
GENESIS_BLOCK_FILE=$CHANNEL_ARTIFACTS_DIR/genesis.block
CHANNEL_TX_FILE=$CHANNEL_ARTIFACTS_DIR/$CHANNEL_ID.tx
CHANNEL_BLOCK_FILE=$CHANNEL_ARTIFACTS_DIR/$CHANNEL_ID.block
CHAINCODE_NAME=mycc1

logr "create genesis block"

configtxgen -profile SampleSingleMSPBFTsmart -outputBlock $GENESIS_BLOCK_FILE -channelID orderer-system-channel
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

configtxgen -inspectChannelCreateTx $CHANNEL_TX_FILE > /data/channel-config.json &
sleep 5

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
initPeerVars ${PORGS[0]} 0
logr "orderer connection $ORDERER_CONN_ARGS"
peer channel create --logging-level=DEBUG -c $CHANNEL_ID -f $CHANNEL_TX_FILE $ORDERER_CONN_ARGS --outputBlock $CHANNEL_BLOCK_FILE 2>&1 | tee -a /data/logs/create_channel.log &

sleep 10

logr "ALL peers join the channel"
for ORG in $PEER_ORGS; do
	COUNT=0
	while [[ "$COUNT" -lt $NUM_PEERS ]]; do
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
	initPeerVars $ORG 0
	
	ANCHOR_TX_FILE=$CHANNEL_ARTIFACTS_DIR/$ORG/anchors.tx
	echo $ORDERER_CONN_ARGS
	peer channel update -c $CHANNEL_ID -f $ANCHOR_TX_FILE $ORDERER_CONN_ARGS
	sleep 2
done
logr "Update the anchor peers: DONE"

initPeerVars org1 0
peer channel getinfo -c $CHANNEL_ID $ORDERER_CONN_ARGS 2>&1 | tee -a /data/logs/channel.log &
sleep 1

logr "install chaincode on peer0"
for ORG in $PEER_ORGS; do
	initPeerVars $ORG 0

	logr "Install chaincode for $PEER_HOST ..."
	peer chaincode install -n $CHAINCODE_NAME -v 1.0 -p github.com/hyperledger/fabric-samples/chaincode/chaincode_example02/go 2>&1 | tee -a /data/logs/${PEER_HOST}_install.log &

	sleep 1
done

sleep 40

logr "instantiate chaincode on ${PORGS[0]} peer0"
POLICY="OR('org1MSP.member','org2MSP.member')"
initPeerVars ${PORGS[0]} 0

peer chaincode instantiate -C $CHANNEL_ID -n ${CHAINCODE_NAME} -v 1.0 -P ${POLICY} -c '{"Args":["init","a","100","b","200"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a /data/logs/instantiate.log &

sleep 80

peer chaincode list --instantiated -C $CHANNEL_ID 2>&1 | tee -a /data/logs/${PEER_HOST}_installed.log &
sleep 10

logr "query chaincode"
logr "query a"
peer chaincode query -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["query","a"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a /data/logs/query1.log &

sleep 10

initPeerVars ${PORGS[1]} 0
logr "invoke a -> b"
peer chaincode invoke -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["invoke","a","b","10"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a /data/logs/query2.log &

sleep 10
logr "query a (2)"
peer chaincode query -C $CHANNEL_ID -n ${CHAINCODE_NAME} -c '{"Args":["query","a"]}' $ORDERER_CONN_ARGS 2>&1 | tee -a /data/logs/query3.log &

sleep 10

logr "get newest block"
peer channel fetch newest /etc/hyperledger/channel-artifacts/block.txt -c $CHANNEL_ID $ORDERER_CONN_ARGS 2>&1 | tee -a /data/logs/getblock.log &

sleep 10
logr "FINISHED"

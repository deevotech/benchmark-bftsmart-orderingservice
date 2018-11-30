SDIR=$(dirname "$0")
source $SDIR/env.sh

export RUN_SUMPATH=/data/logs/ca/msp.log

declare -A NODES='('${NODE_COUNT}')'

function enrollCAAdmin() {
	cleanOrCreateDirectory $FABRIC_CA_CLIENT_HOME

	logr "Enrolling with $ENROLLMENT_URL as bootstrap identity to $FABRIC_CA_CLIENT_HOME..."
	fabric-ca-client enroll -d -u $ENROLLMENT_URL -M $FABRIC_CA_CLIENT_HOME --enrollment.profile tls
}

function getCACerts() {
	if [ $# -ne 1 ]; then
		echo "Usage: getCACerts <ORG>: $*"
		exit 1
	fi

	local org=$1
	logr "Getting CA certificates ..."

	cleanOrCreateDirectory $ORG_MSP_DIR
	logr "Getting CA certs for organization $org and storing in $ORG_MSP_DIR"
	fabric-ca-client getcacert -d -M $ORG_MSP_DIR -u $ENROLLMENT_URL --enrollment.profile tls
	fabric-ca-client getcacert -d -M $ORG_MSP_DIR -u $ENROLLMENT_URL

	cp $ORG_MSP_DIR/tlscacerts/* $CRYPTO_DIR/cacerts/${org}/tls.${org}.pem
}

function registerPeerIdentities() {
	if [ $# -ne 2 ]; then
		echo "Usage: registerPeerIdentities <ORG> <NUM>: $*"
		exit 1
	fi

	local org=$1
	local num=$2

	fabric-ca-client register -d --id.name $PEER_NAME --id.secret $PEER_PASS --id.type peer --id.affiliation $org --id.attrs 'admin=true:ecert'

	if [ $num -eq 0 ]; then
		logr "Registering admin identity with $ADMIN_NAME:$ADMIN_PASS"
		# The admin identity has the "admin" attribute which is added to ECert by default
		fabric-ca-client register -d --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.affiliation $org --id.attrs '"hf.Registrar.Roles=user"' --id.attrs '"hf.Registrar.Attributes=*"' --id.attrs 'hf.Revoker=true,hf.GenCRL=true,admin=true:ecert'
		logr "Registering user identity with $USER_NAME:$USER_PASS"
		fabric-ca-client register -d --id.name $USER_NAME --id.secret $USER_PASS --id.affiliation $org --id.attrs '"hf.Registrar.Roles=user"'
	fi
}

function createPeerMSPs() {
	if [ $# -ne 2 ]; then
		echo "Usage: createPeerMSPs <ORG> <NUM>: $*"
		exit 1
	fi

	local org=$1
	local num=$2

	if [ $num -eq 0 ]; then
		logr "Generate client TLS cert and key pair for the admin of $org"
		genMSPCerts $PEER_HOST $ADMIN_NAME $ADMIN_PASS $org $CA_HOST $ADMIN_CERT_DIR/msp
		cleanOrCreateDirectory $ADMIN_CERT_DIR/msp/cacerts
		cp $ROOT_CA_CERTFILE $ADMIN_CERT_DIR/msp/cacerts

		cleanOrCreateDirectory $ADMIN_CERT_DIR/tls
		cp $ADMIN_CERT_DIR/msp/signcerts/* $ADMIN_CERT_DIR/tls/server.crt
		cp $ADMIN_CERT_DIR/msp/keystore/* $ADMIN_CERT_DIR/tls/server.key

		cleanOrCreateDirectory $ADMIN_CERT_DIR/msp/admincerts
		cp $ADMIN_CERT_DIR/msp/signcerts/* $ADMIN_CERT_DIR/msp/admincerts/admin@$org.pem

		logr "Copy the org's admin cert into channel MSP directory"

		cleanOrCreateDirectory $ORG_MSP_DIR/admincerts
		cp $ADMIN_CERT_DIR/msp/signcerts/* $ORG_MSP_DIR/admincerts/admin@$org.pem
	fi

	logr "Generate server TLS cert and key pair for the peer"
	cleanOrCreateDirectory $PEER_CERT_DIR
	genMSPCerts $PEER_HOST $PEER_NAME $PEER_PASS $org $CA_HOST $PEER_CERT_DIR/msp
	cleanOrCreateDirectory $PEER_CERT_DIR/msp/cacerts
	cp $ROOT_CA_CERTFILE $PEER_CERT_DIR/msp/cacerts

	cleanOrCreateDirectory $PEER_CERT_DIR/tls
	cp $PEER_CERT_DIR/msp/signcerts/* $PEER_CERT_DIR/tls/server.crt
	cp $PEER_CERT_DIR/msp/keystore/* $PEER_CERT_DIR/tls/server.key

	cleanOrCreateDirectory $PEER_CERT_DIR/msp/admincerts
	cp $ADMIN_CERT_DIR/msp/signcerts/* $PEER_CERT_DIR/msp/admincerts/admin@$org.pem
}

function registerOrdererIdentities() {
	if [ $# -ne 2 ]; then
		echo "Usage: registerOrdererIdentities <ORG> <NUM>: $*"
		exit 1
	fi

	local org=$1
	local num=$2

	fabric-ca-client register -d --id.name $ORDERER_NAME --id.secret $ORDERER_PASS --id.type orderer --id.affiliation $org --id.attrs 'admin=true:ecert'

	if [ $num -eq 0 ]; then
		logr "Registering admin identity with $ADMIN_NAME:$ADMIN_PASS"
		# The admin identity has the "admin" attribute which is added to ECert by default
		fabric-ca-client register -d --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.affiliation $org --id.attrs '"hf.Registrar.Roles=user"' --id.attrs '"hf.Registrar.Attributes=*"' --id.attrs 'hf.Revoker=true,hf.GenCRL=true,admin=true:ecert'
	fi
}

function createOrdererMSPs() {
	if [ $# -ne 2 ]; then
		echo "Usage: createOrdererMSPs <ORG> <NUM>: $*"
		exit 1
	fi

	local org=$1
	local num=$2

	if [ $num -eq 0 ]; then
		logr "Generate client TLS cert and key pair for the admin of $org"
		genMSPCerts $ORDERER_HOST $ADMIN_NAME $ADMIN_PASS $org $CA_HOST $ADMIN_CERT_DIR/msp
		cleanOrCreateDirectory $ADMIN_CERT_DIR/msp/cacerts
		cp $ROOT_CA_CERTFILE $ADMIN_CERT_DIR/msp/cacerts

		cleanOrCreateDirectory $ADMIN_CERT_DIR/tls
		cp $ADMIN_CERT_DIR/msp/signcerts/* $ADMIN_CERT_DIR/tls/server.crt
		cp $ADMIN_CERT_DIR/msp/keystore/* $ADMIN_CERT_DIR/tls/server.key

		cleanOrCreateDirectory $ADMIN_CERT_DIR/msp/admincerts
		cp $ADMIN_CERT_DIR/msp/signcerts/* $ADMIN_CERT_DIR/msp/admincerts/admin@$org.pem

		logr "Copy the org's admin cert into channel MSP directory"

		cleanOrCreateDirectory $ORG_MSP_DIR/admincerts
		cp $ADMIN_CERT_DIR/msp/signcerts/* $ORG_MSP_DIR/admincerts/admin@$org.pem
	fi

	logr "Generate server TLS cert and key pair for the orderer"
	cleanOrCreateDirectory $ORDERER_CERT_DIR
	genMSPCerts $ORDERER_HOST $ORDERER_NAME $ORDERER_PASS $org $CA_HOST $ORDERER_CERT_DIR/msp
	cleanOrCreateDirectory $ORDERER_CERT_DIR/msp/cacerts
	cp $ROOT_CA_CERTFILE $ORDERER_CERT_DIR/msp/cacerts

	cleanOrCreateDirectory $ORDERER_CERT_DIR/tls
	cp $ORDERER_CERT_DIR/msp/signcerts/* $ORDERER_CERT_DIR/tls/server.crt
	cp $ORDERER_CERT_DIR/msp/keystore/* $ORDERER_CERT_DIR/tls/server.key

	cleanOrCreateDirectory $ORDERER_CERT_DIR/msp/admincerts
	cp $ADMIN_CERT_DIR/msp/signcerts/* $ORDERER_CERT_DIR/msp/admincerts/admin@$org.pem
}

function registerReplicaAdmin() {
	if [ $# -ne 1 ]; then
		echo "Usage: registerReplicaAdmin <ORG>: $*"
		exit 1
	fi

	local org=$1

	logr "Registering admin identity with $NODE_ORG_ADMIN:$NODE_ORG_ADMIN_PW"
	# The admin identity has the "admin" attribute which is added to ECert by default
	fabric-ca-client register -d --id.name $NODE_ORG_ADMIN --id.secret $NODE_ORG_ADMIN_PW --id.affiliation $org --id.attrs '"hf.Registrar.Roles=user"' --id.attrs '"hf.Registrar.Attributes=*"' --id.attrs 'hf.Revoker=true,hf.GenCRL=true,admin=true:ecert'
}

function createReplicaMSPsAndCerts() {
	if [ $# -ne 2 ]; then
		echo "Usage: createReplicaMSPsAndCerts <ORG> <NUM>: $*"
		exit 1
	fi

	local org=$1
	local num=$2

	logr "Generate client TLS cert and key pair for the admin of $org"
	genMSPCerts bft.node $NODE_ORG_ADMIN $NODE_ORG_ADMIN_PW $org $CA_HOST $ADMIN_CERT_DIR/msp
	cleanOrCreateDirectory $ADMIN_CERT_DIR/msp/cacerts
	cp $ROOT_CA_CERTFILE $ADMIN_CERT_DIR/msp/cacerts

	cleanOrCreateDirectory $ADMIN_CERT_DIR/tls
	cp $ADMIN_CERT_DIR/msp/signcerts/* $ADMIN_CERT_DIR/tls/server.crt
	cp $ADMIN_CERT_DIR/msp/keystore/* $ADMIN_CERT_DIR/tls/server.key

	cleanOrCreateDirectory $ADMIN_CERT_DIR/msp/admincerts
	cp $ADMIN_CERT_DIR/msp/signcerts/* $ADMIN_CERT_DIR/msp/admincerts/admin@$org.pem

	logr "Copy the org's admin cert into channel MSP directory"

	cleanOrCreateDirectory $ORG_MSP_DIR/admincerts
	cp $ADMIN_CERT_DIR/msp/signcerts/* $ORG_MSP_DIR/admincerts/admin@$org.pem

	logr "Generate server TLS cert and key pair for the nodes"

	NODES_CRT_DIR=$LOCAL_MSP_DIR/$org/certs
	NODES_KEY_DIR=$LOCAL_MSP_DIR/$org/keys
	cleanOrCreateDirectory $NODES_CRT_DIR
	cleanOrCreateDirectory $NODES_KEY_DIR

	cp $ORDERER_CERT_DIR/tls/server.crt $NODES_CRT_DIR/cert1000.pem
	cp $ORDERER_CERT_DIR/tls/server.key $NODES_KEY_DIR/cert1000.key

	# create users for ordering nodes
	for ((c = 0; c < $num; c++)); do
		NODE_HOST_NAME="node${c}.deevo.io"
		NODE_USER="node-${c}"
		NODE_PASS="node-${c}-pw"
		fabric-ca-client register -d --id.name $NODE_USER --id.secret $NODE_PASS --id.affiliation $org

		NODES_MSP_DIR=$LOCAL_MSP_DIR/$org/users/$NODE_USER/msp

		cleanOrCreateDirectory $NODES_MSP_DIR
		genMSPCerts $NODE_HOST_NAME $NODE_USER $NODE_PASS $org $CA_HOST $NODES_MSP_DIR

		cp $NODES_MSP_DIR/signcerts/* $NODES_CRT_DIR/cert${c}.pem
		cp $NODES_MSP_DIR/keystore/* $NODES_KEY_DIR/cert${c}.key

		cleanOrCreateDirectory $NODES_MSP_DIR/admincerts
		cp $ADMIN_CERT_DIR/msp/signcerts/* $NODES_MSP_DIR/admincerts/admin@$org.pem
	done
}

function main() {
	# wait for CA servers
	sleep 15

	for ORG in ${PEER_ORGS[*]}; do
		initOrgVars $ORG
		enrollCAAdmin
		getCACerts $ORG

		COUNT=0
		while [ $COUNT -lt ${NODES[$ORG]} ]; do
			log "Generate msp for peer${COUNT}.${ORG}"

			initPeerVars $ORG ${COUNT}
			registerPeerIdentities $ORG ${COUNT}
			createPeerMSPs $ORG ${COUNT}

			COUNT=$((COUNT + 1))
		done
	done

	initOrgVars $ORDERER_ORG
	enrollCAAdmin
	getCACerts $ORDERER_ORG

	COUNT=0
	while [ $COUNT -lt ${NODES[$ORDERER_ORG]} ]; do
		log "Generate msp for orderer${COUNT}.${ORDERER_ORG}"

		initOrdererVars $ORDERER_ORG ${COUNT}
		registerOrdererIdentities $ORDERER_ORG ${COUNT}
		createOrdererMSPs $ORDERER_ORG ${COUNT}

		COUNT=$((COUNT + 1))
	done

	initOrgVars $REPLICAS_ORG
	enrollCAAdmin
	getCACerts $REPLICAS_ORG

	export NODE_ORG_ADMIN=replicas-admin
	export NODE_ORG_ADMIN_PW=replicas-admin-pw
	registerReplicaAdmin $REPLICAS_ORG
	createReplicaMSPsAndCerts $REPLICAS_ORG ${NODES[$REPLICAS_ORG]}
}

main

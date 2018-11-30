#!/bin/bash

SDIR=$(dirname "$0")
source $SDIR/env.sh

export RUN_SUMPATH=/data/logs/ca/ca-${ORG}.log

mkdir -p ${FABRIC_CA_SERVER_HOME}
rm -rf ${FABRIC_CA_SERVER_HOME}/*

# mkdir -p /etc/hyperledger/fabric-ca-server-config
# rm -rf /etc/hyperledger/fabric-ca-server-config/*
export FABRIC_CA_SERVER_CONFIG=$FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml
export BOOTSTRAP_USER_PASS=$BOOTSTRAP_USER:$BOOTSTRAP_PASS

logr "Init CA server"

echo "# Version of config file
version: 1.2.0

# Server listening port (default: 7054)
port: 7054

# Enables debug logging (default: false)
debug: false

# Size limit of an acceptable CRL in bytes (default: 512000)
crlsizelimit: 512000

#############################################################################
crl:
  expiry: 24h

#############################################################################
registry:
  # Maximum number of times a password/secret can be reused for enrollment
  # (default: -1, which means there is no limit)
  maxenrollments: -1

  # Contains identity information which is used when LDAP is disabled
  identities:
    - name: ${BOOTSTRAP_USER}
      pass: ${BOOTSTRAP_PASS}
      type: client
      affiliation: \"\"
      attrs:
        hf.Registrar.Roles: \"*\"
        hf.Registrar.DelegateRoles: \"*\"
        hf.Revoker: true
        hf.GenCRL: true
        hf.Registrar.Attributes: \"*\"
        hf.AffiliationMgr: true

#############################################################################
#  Database section
#############################################################################
db:
  type: sqlite3
  datasource: fabric-ca-server.db
  tls:
      enabled: false
      certfiles:
      client:
        certfile:
        keyfile:

#############################################################################
# Affiliations section. Fabric CA server can be bootstrapped with the
# affiliations specified in this section. Affiliations are specified as maps.
#############################################################################
affiliations:
  $ORG: []

#############################################################################
#  Signing section
#############################################################################
signing:
    default:
      usage:
        - digital signature
      expiry: 8760h
    profiles:
      ca:
        usage:
          - cert sign
          - crl sign
          - digital signature
          - key encipherment
        expiry: 43800h
        caconstraint:
          isca: true
          maxpathlen: 0
      tls:
        usage:
            - signing
            - key encipherment
            - server auth
            - client auth
            - key agreement
        expiry: 8760h

###########################################################################
#  Certificate Signing Request (CSR) section.
###########################################################################
csr:
  cn: fabric-ca-server
  names:
    - C: US
      ST: California
      L:
      O: ${ORG}
      OU: COP
  hosts:
    - ubuntu
    - localhost
  ca:
    expiry: 131400h
    pathlength: 1

#############################################################################
# BCCSP (BlockChain Crypto Service Provider) section is used to select which
# crypto library implementation to use
#############################################################################
bccsp:
    default: SW
    sw:
        hash: SHA2
        security: 256
        filekeystore:
            # The directory used for the software file-based keystore
            keystore: msp/keystore

cacount:

cafiles:

intermediate:
  parentserver:
    url:
    caname:

  enrollment:
    hosts:
    profile:
    label:

  tls:
    certfiles:
    client:
      certfile:
      keyfile:
" >> $FABRIC_CA_SERVER_CONFIG

fabric-ca-server init -b $BOOTSTRAP_USER_PASS

# Start the root CA

logr "Start CA server"
fabric-ca-server start -b $BOOTSTRAP_USER_PASS -d 2>&1 | tee -a $RUN_SUMPATH

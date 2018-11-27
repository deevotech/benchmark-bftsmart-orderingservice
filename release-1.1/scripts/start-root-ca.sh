#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

set -e

# Initialize the root CA
rm -rf $FABRIC_CA_SERVER_HOME/*
fabric-ca-server init -b $BOOTSTRAP_USER_PASS

# Copy the root CA's signing certificate to the data directory to be used by others
cp $FABRIC_CA_SERVER_HOME/ca-cert.pem $TARGET_CERTFILE
mkdir -p /data/${FABRIC_CA_SERVER_CSR_HOSTS}-home
cp -R ${FABRIC_CA_SERVER_HOME}/* /data/${FABRIC_CA_SERVER_CSR_HOSTS}-home/
# Add the custom orgs
for o in $FABRIC_ORGS; do
   aff=$aff"\n   $o: []"
done
aff="${aff#\\n   }"
sed -i "/affiliations:/a \\   $aff" \
   $FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml
sed -i "s/OU: Fabric/OU: COP/g" \
   $FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml

# Start the root CA
fabric-ca-server version > /data/version-fabric-ca.txt
fabric-ca-server start --tls.enabled=true
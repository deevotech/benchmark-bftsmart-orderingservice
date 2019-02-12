#!/bin/bash
docker build -t=bftsmart/base:1.4.1 -< ../docker-images/base.dockerfile
docker build -t=bftsmart/bftsmart-orderingnode:1.4.1 -< ../docker-images/orderingnode.dockerfile
docker build -t=bftsmart/bftsmart-fabric-tools -< ../docker-images/fabrictool.dockerfile
docker build -t=bftsmart/bftsmart-fabric-ca -< ../docker-images/fabricca.dockerfile
docker build -t=bftsmart/bftsmart-orderer:1.4.1 -< ../docker-images/orderer.dockerfile
docker build -t=bftsmart/bftsmart-peer:1.4.1 -< ../docker-images/peer.dockerfile
# docker build -t=bftsmart/bftsmart-couchdb -< ../docker-images/couchdb.dockerfile
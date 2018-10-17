#!/bin/bash
docker build -t=bftsmart/base:1.2.0 -< ../docker-images-1.2/base.dockerfile
docker build -t=bftsmart/bftsmart-orderingnode:1.2.0 -< ../docker-images-1.2/orderingnode.dockerfile
docker build -t=bftsmart/bftsmart-fabric-tools -< ../docker-images-1.2/fabrictool.dockerfile
docker build -t=bftsmart/bftsmart-fabric-ca -< ../docker-images-1.2/fabricca.dockerfile
docker build -t=bftsmart/bftsmart-orderer:1.2.0 -< ../docker-images-1.2/orderer.dockerfile
docker build -t=bftsmart/bftsmart-peer:1.2.0 -< ../docker-images-1.2/peer.dockerfile
# docker build -t=bftsmart/bftsmart-couchdb -< ../docker-images-1.2/couchdb.dockerfile
#!/bin/bash
docker build -t=bftsmart/bftsmart-common:x86_64-1.1.1 -< ../docker-images/Dockerfile-common
docker build -t=bftsmart/bftsmart-orderingnode:x86_64-1.1.1 -< ../docker-images/Dockerfile-orderingnode
docker build -t=bftsmart/bftsmart-tools -< ../docker-images/Dockerfile-tools
docker build -t=bftsmart/bftsmart-fabric-tools -< ../docker-images/Dockerfile-fabrictool
docker build -t=bftsmart/bftsmart-fabric-ca -< ../docker-images/Dockerfile-fabricca
docker build -t=bftsmart/bftsmart-peer:x86_64-1.1.1 -< ../docker-images/Dockerfile-peer
docker build -t=bftsmart/bftsmart-frontendnode:x86_64-1.1.1 -< ../docker-images/Dockerfile-frontendnode
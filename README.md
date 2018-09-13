# benchmark-bftsmart-orderingservice
- Clone https://github.com/hyperledger/caliper
- Pre-requisites
    - NodeJS 8.X
    - node-gyp
    - Docker
    - Docker-compose
- Install blockchain SDKs
    - Fabric
        - npm install grpc@1.10.1 fabric-ca-client@1.1.2 fabric-client@1.1.2
- Copy project to capiler
    - cp -R caliperconfig/benchmark/simple caliper/benchmark/simple
    - cp -R caliperconfig/network/fabric/mynetwork caliper/network/fabric/mynetwork
        - mynetwork folder contains crypto-config of network
    - cp -R src/fabric caliper/src
- Run benmark
    - npm test -- simple -c ./benchmark/simple/config.json -n ./benchmark/simple/myfabric-remote.json
 

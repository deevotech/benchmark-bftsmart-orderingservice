FROM golang:1.11.1

ENV DEBIAN_FRONTEND noninteractive

# Only useful for this Dockerfile
ENV FABRIC_ROOT=$GOPATH/src/github.com/hyperledger/fabric
ENV CHAINTOOL_RELEASE=1.1.3

# Architecture of the node
ENV ARCH=amd64
# version for the base images (baseos, baseimage, ccenv, etc.), used in core.yaml as BaseVersion
ENV BASEIMAGE_RELEASE=0.4.14
# BASE_VERSION is required in core.yaml for the runtime fabric-baseos
ENV BASE_VERSION=1.4.1
# version for the peer/orderer binaries, the community version tracks the hash value like 1.0.0-snapshot-51b7e85
# PROJECT_VERSION is required in core.yaml to build image for cc container
ENV PROJECT_VERSION=1.4.1
# generic golang cc builder environment (core.yaml): builder: $(DOCKER_NS)/fabric-ccenv:$(ARCH)-$(PROJECT_VERSION)
ENV DOCKER_NS=hyperledger
# for golang or car's baseos for cc runtime: $(BASE_DOCKER_NS)/fabric-baseos:$(ARCH)-$(BASEIMAGE_RELEASE)
ENV BASE_DOCKER_NS=hyperledger
ENV LD_FLAGS="-X github.com/hyperledger/fabric/common/metadata.Version=${BASE_VERSION} \
             -X github.com/hyperledger/fabric/common/metadata.BaseVersion=${BASEIMAGE_RELEASE} \
             -X github.com/hyperledger/fabric/common/metadata.BaseDockerLabel=org.hyperledger.fabric \
             -X github.com/hyperledger/fabric/common/metadata.DockerNamespace=hyperledger \
             -X github.com/hyperledger/fabric/common/metadata.BaseDockerNamespace=hyperledger \
             -X github.com/hyperledger/fabric/common/metadata.Experimental=true"

# Install development dependencies
RUN apt-get update \
        && apt-get install -y apt-utils python-dev \
        && apt-get install -y libsnappy-dev zlib1g-dev libbz2-dev libyaml-dev libltdl-dev libtool libc6 \
        && apt-get install -y python-pip \
        && apt-get install -y tree jq unzip\
        && rm -rf /var/cache/apt

# ca-server and ca-client will check the following env in order, to get the home cfg path
ENV FABRIC_CA_HOME /etc/hyperledger/fabric-ca-server
ENV FABRIC_CA_CLIENT_HOME $HOME/fabric-ca-client
ENV CA_CFG_PATH /etc/hyperledger/fabric-ca

# This is go simplify this Dockerfile
ENV FABRIC_CA_ROOT $GOPATH/src/github.com/hyperledger/fabric-ca

RUN mkdir -p $GOPATH/src/github.com/hyperledger \
        $FABRIC_CA_CLIENT_HOME \
        $CA_CFG_PATH 

RUN cd $GOPATH/src/github.com/hyperledger \
    && wget -O $GOPATH/src/github.com/hyperledger/fabric-ca.zip https://github.com/deevotech/fabric-ca/archive/release-1.4.zip \
    && unzip fabric-ca.zip \
    && rm fabric-ca.zip \
    && mv fabric-ca-release-1.4 fabric-ca

RUN cd $GOPATH/src/github.com/hyperledger/fabric-ca/cmd/fabric-ca-client \
    && go build \
    && cp fabric-ca-client /usr/local/bin/ 

RUN export PATH=$PATH:/usr/local/bin/

VOLUME $FABRIC_CA_CLIENT_HOME

# Peer config path
ENV FABRIC_CFG_PATH=/etc/hyperledger/fabric
RUN mkdir -p /var/hyperledger/db \
        /var/hyperledger/production \
	$GOPATH/src/github.com/hyperledger \
	$FABRIC_CFG_PATH \
        /chaincode/input \
        /chaincode/output

# install chaintool
RUN curl -fL https://nexus.hyperledger.org/content/repositories/releases/org/hyperledger/fabric/hyperledger-fabric/chaintool-${CHAINTOOL_RELEASE}/hyperledger-fabric-chaintool-${CHAINTOOL_RELEASE}.jar > /usr/local/bin/chaintool \
        && chmod a+x /usr/local/bin/chaintool

# install gotools
RUN go get github.com/golang/protobuf/protoc-gen-go \
        && go get github.com/kardianos/govendor \
        && go get golang.org/x/lint/golint \
        && go get golang.org/x/tools/cmd/goimports \
        && go get github.com/onsi/ginkgo/ginkgo \
        && go get github.com/axw/gocov/... \
        && go get github.com/client9/misspell/cmd/misspell \
        && go get github.com/AlekSi/gocov-xml

# Clone the Hyperledger Fabric code and cp sample config files
RUN cd $GOPATH/src/github.com/hyperledger \
        && wget https://github.com/deevotech/fabric/archive/release-1.4.zip \
        && unzip release-1.4.zip \
        && rm release-1.4.zip \
        && mv fabric-release-1.4 fabric \
        && cp $FABRIC_ROOT/devenv/limits.conf /etc/security/limits.conf 
        # && cp -r $FABRIC_ROOT/sampleconfig/* $FABRIC_CFG_PATH/ \
        # && cp $FABRIC_ROOT/examples/e2e_cli/configtx.yaml $FABRIC_CFG_PATH/ \
        # && cp $FABRIC_ROOT/examples/e2e_cli/crypto-config.yaml $FABRIC_CFG_PATH/

# install configtxgen, cryptogen and configtxlator
RUN cd $FABRIC_ROOT/ \
        && go install -tags "experimental" -ldflags "${LD_FLAGS}" github.com/hyperledger/fabric/common/tools/configtxgen \
        && go install -tags "experimental" -ldflags "${LD_FLAGS}" github.com/hyperledger/fabric/common/tools/cryptogen \
        && go install -tags "experimental" -ldflags "${LD_FLAGS}" github.com/hyperledger/fabric/common/tools/configtxlator


# Install eventsclient
RUN cd $FABRIC_ROOT/examples/events/eventsclient \
        && go install \
        && go clean


# The data and config dir, can map external one with -v
VOLUME /var/hyperledger
#VOLUME /etc/hyperledger/fabric


# temporarily fix the `go list` complain problem, which is required in chaincode packaging, see core/chaincode/platforms/golang/platform.go#GetDepoymentPayload
ENV GOROOT=/usr/local/go

WORKDIR $FABRIC_ROOT

# This is only a workaround for current hard-coded problem when using as fabric-baseimage.
RUN ln -s $GOPATH /opt/gopath
LABEL org.hyperledger.fabric.version=${PROJECT_VERSION} \
      org.hyperledger.fabric.base.version=${BASEIMAGE_RELEASE}

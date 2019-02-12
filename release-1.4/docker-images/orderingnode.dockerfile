FROM ubuntu:18.04

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get clean && \
rm -rf /var/lib/apt/lists/*;

RUN apt-get update -y && \
apt-get install -y openjdk-8* && \
rm -rf /var/lib/apt/lists/*;

RUN update-alternatives --config javac

ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64
RUN export JAVA_HOME

RUN apt-get update && \
apt-get install -y ant && \
apt-get install -y unzip && \
apt-get install -y wget && \
apt-get install -y autoconf && \
apt-get install -y build-essential && \
apt-get install -y libc6-dev-i386 && \
apt-get clean;

ENV GOPATH /go
RUN mkdir -p $GOPATH/src/github.com/hyperledger
WORKDIR $GOPATH/src/github.com/hyperledger

RUN wget https://github.com/mcfunley/juds/archive/master.zip --output-document=/tmp/juds.zip;

RUN echo $(ls $JAVA_HOME/bin)

RUN unzip /tmp/juds.zip -d /tmp/juds;
WORKDIR /tmp/juds/juds-master;
RUN cd /tmp/juds/juds-master && \
./autoconf.sh && \
./configure && \
make && \
make install;
RUN rm -rf /tmp/juds.zip
RUN rm -rf /tmp/juds

RUN wget https://github.com/deevotech/fabric-orderingservice/archive/release-1.4.zip --output-document=/tmp/fabric-orderingservice.zip
RUN unzip /tmp/fabric-orderingservice.zip -d $GOPATH/src/github.com/hyperledger/
RUN mv $GOPATH/src/github.com/hyperledger/fabric-orderingservice-release-1.4 $GOPATH/src/github.com/hyperledger/fabric-orderingservice
WORKDIR $GOPATH/src/github.com/hyperledger/fabric-orderingservice
RUN cd $GOPATH/src/github.com/hyperledger/fabric-orderingservice && \
ant clean && \
ant;
RUN rm -rf /tmp/fabric-orderingservice.zip;
RUN mkdir -p  /etc/bftsmart-orderer;
RUN mkdir -p /etc/bftsmart-orderer/config;
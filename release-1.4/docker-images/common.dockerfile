FROM ubuntu:18.04

RUN apt-get update
RUN apt-get install -f
RUN apt-get -y install software-properties-common debconf-utils git build-essential python-pip python-dev curl 
RUN apt-get install -y --no-install-recommends apt-utils && \
apt-get install -y openjdk-8* && \
apt-get install -y ant && \
apt-get install -y unzip && \
apt-get install -y wget && \
apt-get install -y libc6-dev-i386 && \
apt-get install -y autoconf && \
apt-get install -y make && \
apt-get clean && \
rm -rf /var/lib/apt/lists/*;

RUN apt-get update && \
apt-get install -y ca-certificates-java && \
apt-get clean && \
update-ca-certificates -f && \
rm -rf /var/lib/apt/lists/*;

ENV JAVA_HOME /usr/lib/jvm/java-8-openjdk-amd64/
RUN export JAVA_HOME

RUN curl -O https://dl.google.com/go/go1.11.1.linux-amd64.tar.gz
RUN tar -xvf go1.11.1.linux-amd64.tar.gz
RUN mv go /usr/local

ENV PATH=$PATH:/usr/local/go/bin
ENV GOPATH=/go

RUN echo $PATH
RUN echo $GOPATH
RUN /usr/local/go/bin/go version
RUN go version
RUN mkdir -p /go/src
RUN mkdir -p /go/src/github.com
RUN mkdir -p /go/src/github.com/hyperledger
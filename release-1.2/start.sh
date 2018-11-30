#!/bin/bash

set -e

mkdir -p data/channel-artifacts
sudo rm -rf data/channel-artifacts/*
mkdir -p data/network
sudo rm -rf data/network/*
mkdir -p data/logs/network
sudo rm -rf data/logs/network/*

function removeDockerContainers() {
	if [ $# -ne 1 ]; then
		echo "Usage: removeDockerContainers <image name>"
		exit 1
	fi
	local imageName=$1

	for pid in $(docker ps -a -q --filter ancestor=$imageName); do
		if [ $pid != $$ ]; then
			echo "Container of image $imageName is already running $pid"
			docker rm -f $pid
		fi
	done
}

# Remove all containers
removeDockerContainers "bftsmart/bftsmart-orderingnode:1.2.0"
removeDockerContainers "bftsmart/bftsmart-peer:1.2.0"
removeDockerContainers "bftsmart/bftsmart-orderer:1.2.0"
removeDockerContainers "bftsmart/bftsmart-fabric-tools"

docker-compose -f compose/network-solo.yaml up

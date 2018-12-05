#!/bin/bash

set -e

mkdir -p data/logs/marble
sudo rm -rf data/logs/marble/*

containerName=client-node
for pid in $(docker ps -a -q --filter name=$containerName); do
	if [ $pid != $$ ]; then
		echo "Container of image $containerName is already running $pid"
		docker rm -f $pid
	fi
done

export COMPOSE_PROJECT_NAME=net && docker-compose -f compose/client.yaml up

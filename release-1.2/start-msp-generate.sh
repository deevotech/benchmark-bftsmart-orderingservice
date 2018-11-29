#!/bin/bash

set -e

mkdir -p data/logs
sudo rm -rf data/logs/*
mkdir -p crypto-config/
sudo rm -rf crypto-config/*

# Remove all containers
for pid in $(docker ps -a -q); do
    if [ $pid != $$ ]; then
        echo "Container is already running $pid"
        docker rm -f $pid
    fi
done

docker-compose -f compose/msp-generate.yaml up

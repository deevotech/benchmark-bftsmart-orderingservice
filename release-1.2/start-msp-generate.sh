#!/bin/bash

set -e

mkdir -p data/logs/ca
sudo rm -rf data/logs/ca/*
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

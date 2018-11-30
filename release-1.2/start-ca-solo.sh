#!/bin/bash

set -e

mkdir -p data/logs/ca
sudo rm -rf data/logs/ca/*
mkdir -p crypto-config/orgs
sudo rm -rf crypto-config/orgs/*

# Remove all containers
for pid in $(docker ps -a -q); do
    if [ $pid != $$ ]; then
        echo "Container is already running $pid"
        docker rm -f $pid
    fi
done

export COMPOSE_PROJECT_NAME=net && docker-compose -f compose/ca-solo.yaml up

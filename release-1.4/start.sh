#!/bin/bash

set -e

mkdir -p data
mkdir -p data-config
mkdir -p data/logs
# mkdir -p setup
sudo rm -rf data/channel-artifacts/*
sudo rm -rf data/logs/*
sudo rm -rf data-config/*
mkdir -p data
# sudo rm -rf setup/*
mkdir -p crypto-config/orgs
sudo rm -rf crypto-config/orgs/*

# Remove all containers
for pid in $(docker ps -a -q); do
    if [ $pid != $$ ]; then
        echo "Container is already running $pid"
        docker rm -f $pid
    fi
done

export COMPOSE_PROJECT_NAME=net && docker-compose -f compose/base-solo.yaml up

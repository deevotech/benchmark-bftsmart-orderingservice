#!/bin/bash

set -e

mkdir -p data/logs_1
sudo rm -rf data/logs_1/*

export COMPOSE_PROJECT_NAME=net && docker-compose -f compose/client.yaml up

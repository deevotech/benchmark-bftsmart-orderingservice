#!/bin/bash

set -e

mkdir -p data/logs_2
sudo rm -rf data/logs_2/*

export COMPOSE_PROJECT_NAME=net && docker-compose -f compose/client.yaml up

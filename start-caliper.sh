#!/bin/bash

set -e

mkdir -p ./data
mkdir -p ./data/logs
mkdir -p ./setup
sudo rm -rf data/*
mkdir -p data
mkdir data/logs
sudo rm -rf setup/*
export COMPOSE_PROJECT_NAME=net && docker-compose -f docker-composer-caliper.yaml up

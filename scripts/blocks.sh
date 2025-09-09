#!/bin/bash

# Exit on error
set -e  

# Create required folders
mkdir -p ./target/blocks_bin
mkdir -p ./target/blocks_bin/rec

# Create virtual environment and install required packages
python3 -m venv ./generators/blocks/venv
source ./generators/blocks/venv/bin/activate
pip3 install electrum_client

# Generate Prover.toml
python3 -m generators.blocks.main

# Deactivate venv
deactivate
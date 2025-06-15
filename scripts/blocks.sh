#!/bin/bash

# Exit on error
set -e  

# Create virtual environment and install required packages
python3 -m venv ./generators/blocks/venv
source ./generators/blocks/venv/bin/activate
pip3 install electrum_client

# Generate Prover.toml
python3 generators/blocks/main.py

# Deactivate venv
deactivate

# Execute the binary
nargo execute --package blocks_bin

# Prove the proof
mkdir -p target
mkdir -p target/blocks_bin
bb prove -b ./target/blocks_bin.json -w ./target/blocks_bin.gz -o ./target/blocks_bin

# Write the VK
bb write_vk -b ./target/blocks_bin.json -o ./target/blocks_bin

# Verify the proof
bb verify -k ./target/blocks_bin/vk -p ./target/blocks_bin/proof -i ./target/blocks_bin/public_inputs
#!/bin/bash

# Exit on error
set -e

# Create virtual environment and install required packages
python3 -m venv ./generators/utils/venv
source ./generators/utils/venv/bin/activate
pip3 install python-bitcoinlib

# Generate Prover.toml
python3 -m generators.p2sh.main

# Deactivate venv
deactivate

# Format noir code
nargo fmt

# Execute the binary
nargo execute --package p2sh

# Prove the proof
mkdir -p target
mkdir -p target/p2sh
bb prove -b ./target/p2sh.json -w ./target/p2sh.gz -o ./target/p2sh

# Write the VK
bb write_vk -b ./target/p2sh.json -o ./target/p2sh

# Verify the proof
bb verify -k ./target/p2sh/vk -p ./target/p2sh/proof -i ./target/p2sh/public_inputs
#!/bin/bash

# Exit on error
set -e

# Create virtual environment and install required packages
python3 -m venv ./generators/utils/venv
source ./generators/utils/venv/bin/activate
pip3 install python-bitcoinlib

# Generate Prover.toml
python3 -m generators.p2pk.main

# Deactivate venv
deactivate

# Format noir code
nargo fmt

# Execute the binary
nargo execute --package p2pk

# Prove the proof
mkdir -p target
mkdir -p target/p2pk
bb prove -b ./target/p2pk.json -w ./target/p2pk.gz -o ./target/p2pk

# Write the VK
bb write_vk -b ./target/p2pk.json -o ./target/p2pk

# Verify the proof
bb verify -k ./target/p2pk/vk -p ./target/p2pk/proof -i ./target/p2pk/public_inputs
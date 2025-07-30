#!/bin/bash

# Exit on error
set -e

# Create virtual environment and install required packages
python3 -m venv ./generators/utils/venv
source ./generators/utils/venv/bin/activate
pip3 install python-bitcoinlib
pip3 install requests 

# Generate Prover.toml
python3 -m generators.p2tr.main

# Deactivate venv
deactivate

# Format noir code
nargo fmt

# Execute the binary
nargo execute --package p2tr

# Prove the proof
mkdir -p target
mkdir -p target/p2tr
bb prove -b ./target/p2tr.json -w ./target/p2tr.gz -o ./target/p2tr

# Write the VK
bb write_vk -b ./target/p2tr.json -o ./target/p2tr

# Verify the proof
bb verify -k ./target/p2tr/vk -p ./target/p2tr/proof -i ./target/p2tr/public_inputs
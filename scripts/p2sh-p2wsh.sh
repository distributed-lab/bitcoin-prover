#!/bin/bash

# Exit on error
set -e

# Create virtual environment and install required packages
python3 -m venv ./generators/utils/venv
source ./generators/utils/venv/bin/activate
pip3 install python-bitcoinlib

# Generate Prover.toml
python3 -m generators.p2sh-p2wsh.main

# Deactivate venv
deactivate

# Format noir code
nargo fmt

# Execute the binary
nargo execute --package p2sh_p2wsh

# Prove the proof
mkdir -p target
mkdir -p target/p2sh_p2wsh
bb prove -b ./target/p2sh_p2wsh.json -w ./target/p2sh_p2wsh.gz -o ./target/p2sh_p2wsh

# Write the VK
bb write_vk -b ./target/p2sh_p2wsh.json -o ./target/p2sh_p2wsh

# Verify the proof
bb verify -k ./target/p2sh_p2wsh/vk -p ./target/p2sh_p2wsh/proof -i ./target/p2sh_p2wsh/public_inputs
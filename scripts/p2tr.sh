#!/bin/bash

# Exit on error
set -e

# Generate Prover.toml
python3 generators/p2tr/main.py

# Execute the binary
nargo execute --package p2tr_bin

# Prove the proof
mkdir -p target
mkdir -p target/p2tr_bin
bb prove -b ./target/p2tr_bin.json -w ./target/p2tr_bin.gz -o ./target/p2tr_bin

# Write the VK
bb write_vk -b ./target/p2tr_bin.json -o ./target/p2tr_bin

# Verify the proof
bb verify -k ./target/p2tr_bin/vk -p ./target/p2tr_bin/proof -i ./target/p2tr_bin/public_inputs
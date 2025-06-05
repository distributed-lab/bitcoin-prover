#!/bin/bash

# Exit on error
set -e

# Generate Prover.toml
python3 generators/p2sh/main.py

# Execute the binary
nargo execute --package p2sh_bin

# Prove the proof
mkdir -p target
mkdir -p target/p2sh_bin
bb prove -b ./target/p2sh_bin.json -w ./target/p2sh_bin.gz -o ./target/p2sh_bin

# Write the VK
bb write_vk -b ./target/p2sh_bin.json -o ./target/p2sh_bin

# Verify the proof
bb verify -k ./target/p2sh_bin/vk -p ./target/p2sh_bin/proof -i ./target/p2sh_bin/public_inputs
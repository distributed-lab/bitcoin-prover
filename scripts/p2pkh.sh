#!/bin/bash

# Exit on error
set -e

# Generate Prover.toml
python3 -m generators.p2pkh.main

# Execute the binary
nargo execute --package p2pkh

# Prove the proof
mkdir -p target
mkdir -p target/p2pkh
bb prove -b ./target/p2pkh.json -w ./target/p2pkh.gz -o ./target/p2pkh

# Write the VK
bb write_vk -b ./target/p2pkh.json -o ./target/p2pkh

# Verify the proof
bb verify -k ./target/p2pkh/vk -p ./target/p2pkh/proof -i ./target/p2pkh/public_inputs
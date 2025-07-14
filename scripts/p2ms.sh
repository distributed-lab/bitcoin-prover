#!/bin/bash

# Exit on error
set -e

# Generate Prover.toml
python3 -m generators.p2ms.main

# Execute the binary
nargo execute --package p2ms

# Prove the proof
mkdir -p target
mkdir -p target/p2ms
bb prove -b ./target/p2ms.json -w ./target/p2ms.gz -o ./target/p2ms

# Write the VK
bb write_vk -b ./target/p2ms.json -o ./target/p2ms

# Verify the proof
bb verify -k ./target/p2ms/vk -p ./target/p2ms/proof -i ./target/p2ms/public_inputs
#!/bin/bash

# Exit on error
set -e

if ! pip show python-bitcoinlib >/dev/null 2>&1; then
    echo -e "Pakage 'python-bitcoinlib' is not installed yet.\nRun:\n\tpip3 install python-bitcoinlib==0.12.2"
    exit 1
fi

# Generate Prover.toml
python3 -m generators.p2wsh.main

# Format noir code
nargo fmt

# Execute the binary
nargo execute --package p2wsh

# Prove the proof
mkdir -p target
mkdir -p target/p2wsh
bb prove -b ./target/p2wsh.json -w ./target/p2wsh.gz -o ./target/p2wsh

# Write the VK
bb write_vk -b ./target/p2wsh.json -o ./target/p2wsh

# Verify the proof
bb verify -k ./target/p2wsh/vk -p ./target/p2wsh/proof -i ./target/p2wsh/public_inputs
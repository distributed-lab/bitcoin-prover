#!/bin/bash
python3 ./generator_p2sh/main.py
cd ./p2sh
nargo execute
bb prove -b ./target/p2sh.json -w ./target/p2sh.gz -o ./target/proof 
bb write_vk -b ./target/p2sh.json -o ./target/vk
bb verify -k ./target/vk -p ./target/proof
import json
from typing import Dict
from pullers import BlockHeaderPuller
from block import Block, create_nargo_toml
import logging

def setup_logging():
    logging.basicConfig(level=logging.DEBUG)

def get_config(path: str = "./config.json") -> Dict:
    with open(path, "r") as f:
        return json.load(f)

def main():
    setup_logging()
    config = get_config()

    puller = BlockHeaderPuller(config["gateway"])
    hex_headers =puller.pull_block_headers(config["blocks"]["start"], config["blocks"]["count"])
    blocks = [Block(header) for header in hex_headers]

    nargo_toml = create_nargo_toml(blocks, config["nargo"]["struct_name"])
    with open(config["nargo"]["file_path"], "w") as f:
        f.write(nargo_toml)

if __name__ == "__main__":
    main()

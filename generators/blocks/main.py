import json
from typing import Dict
from pullers import BlockHeaderPuller
from block import Block, create_nargo_toml
import logging

def setup_logging():
    logging.basicConfig(level=logging.DEBUG)

def get_config(path: str = "./generators/blocks/config.json") -> Dict:
    with open(path, "r") as f:
        return json.load(f)

def main():
    setup_logging()
    config = get_config()

    puller = BlockHeaderPuller(config["gateway"])
    hex_headers =puller.pull_block_headers(config["blocks"]["start"], config["blocks"]["count"])
    blocks = [Block(header) for header in hex_headers]

    with open(config["nargo"]["file_path"] + "/src/main.nr", "w") as f:
        f.write(f"""use blocks_lib::{{block::{{BlockHeader, get_block_hash}}, chain::check_chain}};

fn main(blocks: [BlockHeader; {len(blocks)}], last_block_hash: pub str<64>) -> pub bool {{
    assert(
        get_block_hash(blocks[0])
            == "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f",
    );
    assert(get_block_hash(blocks[blocks.len() - 1]) == last_block_hash);
    check_chain(blocks)
}}
""")

    nargo_toml = create_nargo_toml(blocks, config["nargo"]["struct_name"])
    with open(config["nargo"]["file_path"] + "/Prover.toml", "w") as f:
        f.write(f"last_block_hash = \"{blocks[len(blocks) - 1].get_block_hash()}\"\n\n")
        f.write(nargo_toml)

if __name__ == "__main__":
    main()

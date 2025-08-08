import json
from typing import Dict
from pullers import BlockHeaderPuller
from block import Block, create_nargo_toml
import logging
import sys
import subprocess
import ast
import logging

def setup_logging():
    logging.basicConfig(level=logging.DEBUG)

def get_config(path: str = "./generators/blocks/config.json") -> Dict:
    with open(path, "r") as f:
        return json.load(f)

def main():
    setup_logging()
    config = get_config()
    index = 0

    blocks_amount = config["blocks"]["count"]

    if blocks_amount % 2016 != 6:
        print("Amount of blocks must be (2016 * x + 6), where x > 0")
        sys.exit()

    puller = BlockHeaderPuller(config["gateway"])
    hex_headers =puller.pull_block_headers(config["blocks"]["start"], config["blocks"]["count"])
    blocks = [Block(header) for header in hex_headers]

    nargo_toml = create_nargo_toml(blocks[index:2022], "blocks")
    index = 2016

    with open("./app/blocks-recursive/start/Prover.toml", "w") as f:
        f.write(f"last_block_hash = \"{blocks[index].get_block_hash()}\"\n\n")
        f.write(f"timestamp = \"{int.from_bytes(bytes.fromhex(blocks[0].time), byteorder='little')}\"\n\n")
        f.write(nargo_toml)

    logging.debug("nargo execute (start)")
    subprocess.run(['nargo', 'execute', '--package', 'start'], check=True)

    logging.debug("bb proof")
    subprocess.run(['bb', 'prove', 
                    '-s', 'ultra_honk', 
                    '-b', './target/start.json', 
                    '-w', './target/start.gz', 
                    '-o', './target/blocks_bin', 
                    '--output_format', 'bytes_and_fields', 
                    '--honk_recursion', '1', 
                    '--recursive', 
                    '--init_kzg_accumulator'],
                    check=True)
    
    logging.debug("bb write_vk (start)")
    subprocess.run(['bb', 'write_vk', 
                    '-s', 'ultra_honk', 
                    '-b', './target/start.json', 
                    '-o', './target/blocks_bin', 
                    '--output_format', 'bytes_and_fields', 
                    '--honk_recursion', '1', 
                    '--init_kzg_accumulator'],
                    check=True)
    
    subprocess.run(['bb', 'verify', 
                    '-s', 'ultra_honk', 
                    '-k', './target/blocks_bin/vk', 
                    '-p', './target/blocks_bin/proof', 
                    '-i', './target/blocks_bin/public_inputs'],
                    check=True)
    
    with open("./target/blocks_bin/proof_fields.json", "r") as file:
        proof = file.read()

    with open("./target/blocks_bin/vk_fields.json", "r") as file:
        vk = file.read()

    with open("./target/blocks_bin/public_inputs_fields.json", "r") as file:
        pi = file.read()

    logging.debug("nargo compile (recursive)")
    subprocess.run(['nargo', 'compile', '--package', 'rec'], check=True)

    logging.debug("bb write_vk (recursive)")
    subprocess.run(['bb', 'write_vk', 
                    '-s', 'ultra_honk', 
                    '-b', './target/rec.json', 
                    '-o', './target/blocks_bin/rec', 
                    '--output_format', 'bytes_and_fields', 
                    '--honk_recursion', '1', 
                    '--init_kzg_accumulator'],
                    check=True)
    
    with open("./target/blocks_bin/rec/vk_fields.json", "r") as file:
        vk_rec = file.read()
    
    while index < (blocks_amount - 1):
        pi_array = ast.literal_eval(pi)
        if int(pi_array[-2], 16) != 1:
            print("Execution returs false, can't verify blocks chain")
            sys.exit()

        logging.debug(f"Prooving blocks from {index} to {index + 2021}")
        nargo_toml = create_nargo_toml(blocks[index:(index + 2022)], "blocks")
        index += 2016

        with open("./app/blocks-recursive/rec/Prover.toml", "w") as f:
            f.write(f"last_block_hash = \"{blocks[index].get_block_hash()}\"\n\n")
            f.write(f"timestamp = \"{int(pi_array[-1], 16)}\"\n\n")
            f.write(f"verification_key = {vk}\n\n")
            f.write(f"proof = {proof}\n\n")
            f.write(f"public_inputs = {pi}\n\n")
            f.write(nargo_toml)

        logging.debug("nargo execute (recursive)")
        subprocess.run(['nargo', 'execute', '--package', 'rec'], check=True)

        logging.debug("bb prove (recursive)")
        subprocess.run(['bb', 'prove', 
                        '-s', 'ultra_honk', 
                        '-b', './target/rec.json', 
                        '-w', './target/rec.gz', 
                        '-o', './target/blocks_bin/rec', 
                        '--output_format', 'bytes_and_fields', 
                        '--honk_recursion', '1', 
                        '--recursive', 
                        '--init_kzg_accumulator'],
                        check=True)
        
        subprocess.run(['bb', 'verify', 
                        '-s', 'ultra_honk', 
                        '-k', './target/blocks_bin/rec/vk', 
                        '-p', './target/blocks_bin/rec/proof', 
                        '-i', './target/blocks_bin/rec/public_inputs'],
                        check=True)
        
        with open("./target/blocks_bin/rec/proof_fields.json", "r") as file:
            proof = file.read()

        vk = vk_rec

        with open("./target/blocks_bin/rec/public_inputs_fields.json", "r") as file:
            pi = file.read()

    pi_array = ast.literal_eval(pi)
    if int(pi_array[-2], 16) != 1:
        print("Execution returs false, can't verify blocks chain")
        sys.exit()

    print("Recursive proof was created successfully")
    
if __name__ == "__main__":
    main()

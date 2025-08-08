use dep::std;
use blocks_lib::{block::{BlockHeader, get_block_hash}, chain::check_chain};

global HONK_VK_SIZE: u32 = 128;
global HONK_PROOF_SIZE: u32 = 456;
global HONK_IDENTIFIER: u32 = 1;
global PUBLIC_INPUTS: u32 = 70;

global BLOCKS_AMOUNT: u32 = 2022;
global BLOCKS_OFFSET: u32 = 6;

fn main(
    verification_key: [Field; HONK_VK_SIZE],
    proof: [Field; HONK_PROOF_SIZE],
    public_inputs: [Field; PUBLIC_INPUTS],
    blocks: [BlockHeader; BLOCKS_AMOUNT],
    timestamp: i64,
    last_block_hash: pub str<64>,
    last_block_height: pub u32,
    chainwork: pub Field,
) -> pub (bool, i64, u32, Field) {
    std::verify_proof_with_type(verification_key, proof, public_inputs, 0x0, HONK_IDENTIFIER);

    assert(get_block_hash(blocks[blocks.len() - 1]) == last_block_hash);
    let checked =
        check_chain::<BLOCKS_AMOUNT, BLOCKS_OFFSET>(blocks, timestamp, blocks[0].bits, chainwork);
    (checked.0, checked.1, last_block_height + BLOCKS_AMOUNT - BLOCKS_OFFSET, checked.2)
}

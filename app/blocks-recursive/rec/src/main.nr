use dep::std;
use blocks_lib::{block::{BlockHeader, get_block_hash}, chain::check_chain};

global HONK_VK_SIZE: u32 = 128;
global HONK_PROOF_SIZE: u32 = 456;
global HONK_IDENTIFIER: u32 = 1;

fn main(
    verification_key: [Field; HONK_VK_SIZE],
    proof: [Field; HONK_PROOF_SIZE],
    public_inputs: [Field; 67],
    blocks: [BlockHeader; 2017],
    timestamp: pub i64,
    last_block_hash: pub str<64>,
) -> pub (bool, i64) {
    std::verify_proof_with_type(verification_key, proof, public_inputs, 0x0, HONK_IDENTIFIER);

    assert(get_block_hash(blocks[blocks.len() - 1]) == last_block_hash);
    let checked = check_chain(blocks, timestamp, blocks[0].bits);
    (checked.0, checked.1)
}

mod globals;

use dep::std;
use blocks_lib::{
    block::{
        BlockHeader, calc_merkle_state, finalize_merkle_state, get_block_hash,
        get_merkle_node_from_1024_blocks,
    },
    chain::check_chain,
};
use globals::{HONK_IDENTIFIER, HONK_PROOF_SIZE, HONK_VK_SIZE, MERKLE_ROOT_ARRAY_LEN, PUBLIC_INPUTS};
use utils::convert::{bytes_to_hex, hex_to_bytes};

fn main(
    verification_key: [Field; HONK_VK_SIZE],
    proof: [Field; HONK_PROOF_SIZE],
    public_inputs: [Field; PUBLIC_INPUTS],
    blocks: [BlockHeader; 1024],
    timestamps: [u32; 11],
    time_idx: u32,
    last_block_height: u32,
    chainwork: Field,
    mut merkle_state: [[u8; 32]; MERKLE_ROOT_ARRAY_LEN],
    last_block_hash: pub [u8; 32],
    prev_timestamp: u32,
) -> pub ([u32; 11], u32, u32, Field, [u8; 32], u32) {
    std::verify_proof_with_type(verification_key, proof, public_inputs, 0x0, HONK_IDENTIFIER);

    assert(get_block_hash(blocks[blocks.len() - 1]) == bytes_to_hex(last_block_hash));
    let checked = check_chain(
        blocks,
        timestamps,
        time_idx,
        blocks[0].bits,
        last_block_height,
        chainwork,
        prev_timestamp,
    );

    assert(checked.0);

    let last_block_empty = BlockHeader {
        version: 0,
        prev_block: get_block_hash(blocks[1023]),
        merkle_root: str::from([0; 64]),
        timestamp: 0,
        bits: 0,
        nonce: 0,
    };

    let merkle_branch = get_merkle_node_from_1024_blocks(blocks
        .as_slice()
        .push_back(last_block_empty)
        .as_array::<1025>());

    merkle_state = calc_merkle_state(merkle_state, merkle_branch);

    (checked.1, checked.2, checked.3, checked.4, finalize_merkle_state(merkle_state), checked.5)
}

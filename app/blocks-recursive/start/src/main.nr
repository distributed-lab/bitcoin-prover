mod globals;

use blocks_lib::{
    block::{BlockHeader, get_block_hash, get_merkle_node_from_1024_blocks},
    chain::check_chain,
};
use globals::MERKLE_ROOT_ARRAY_LEN;
use utils::convert::bytes_to_hex;

fn main(
    blocks: [BlockHeader; 1025],
    last_block_hash: pub [u8; 32],
) -> pub ([u32; 11], u32, u32, Field, [[u8; 32]; MERKLE_ROOT_ARRAY_LEN], u32) {
    assert(
        get_block_hash(blocks[0])
            == "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f",
    );
    assert(get_block_hash(blocks[1024]) == bytes_to_hex(last_block_hash));

    let mut timestamps = [0; 11];
    timestamps[0] = blocks[0].timestamp;

    let checked = check_chain(
        blocks,
        timestamps,
        1,
        blocks[0].bits,
        0,
        0x100010001,
        blocks[0].timestamp,
    );

    assert(checked.0);

    let merkle_branch = get_merkle_node_from_1024_blocks(blocks);

    let mut merkle_state = [[0; 32]; MERKLE_ROOT_ARRAY_LEN];
    merkle_state[0] = merkle_branch;

    (checked.1, checked.2, checked.3, checked.4, merkle_state, checked.5)
}

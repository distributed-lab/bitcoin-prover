use blocks_lib::{block::{BlockHeader, get_block_hash}, chain::check_chain};

fn main(
    blocks: [BlockHeader; 2017],
    timestamp: pub i64,
    last_block_hash: pub str<64>,
) -> pub (bool, i64) {
    assert(
        get_block_hash(blocks[0])
            == "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f",
    );
    assert(get_block_hash(blocks[blocks.len() - 1]) == last_block_hash);
    let checked = check_chain(blocks, timestamp, blocks[0].bits);
    (checked.0, checked.1)
}

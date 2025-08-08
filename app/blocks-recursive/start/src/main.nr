use blocks_lib::{block::{BlockHeader, get_block_hash}, chain::check_chain};

// 2016 + 6 blocks after new target
global BLOCKS_AMOUNT: u32 = 2022;
global BLOCKS_OFFSET: u32 = 1;

fn main(
    blocks: [BlockHeader; BLOCKS_AMOUNT],
    timestamp: i64,
    last_block_hash: pub str<64>,
    last_checked_block_height: pub u32,
    chainwork: pub Field,
) -> pub (bool, i64, u32, Field) {
    assert(
        get_block_hash(blocks[0])
            == "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f",
    );
    assert(get_block_hash(blocks[BLOCKS_AMOUNT - 1]) == last_block_hash);
    let checked =
        check_chain::<BLOCKS_AMOUNT, BLOCKS_OFFSET>(blocks, timestamp, blocks[0].bits, chainwork);

    (checked.0, checked.1, last_checked_block_height + BLOCKS_AMOUNT - BLOCKS_OFFSET, checked.2)
}

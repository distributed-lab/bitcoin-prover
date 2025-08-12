use blocks_lib::{block::{BlockHeader, get_block_hash}, chain::check_chain};

// 2016 + 6 blocks after new target
global BLOCKS_AMOUNT: u32 = 2022;
global BLOCKS_OFFSET: u32 = 1;

fn main(
    blocks: [BlockHeader; BLOCKS_AMOUNT],
    last_block_hash: pub str<64>,
) -> pub ([u32; 11], u32, u32, Field) {
    assert(
        get_block_hash(blocks[0])
            == "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f",
    );
    assert(get_block_hash(blocks[BLOCKS_AMOUNT - 1]) == last_block_hash);

    let mut timestamps = [0; 11];
    timestamps[0] = blocks[0].timestamp;

    let checked =
        check_chain::<BLOCKS_AMOUNT, BLOCKS_OFFSET>(blocks, timestamps, 1, blocks[0].bits, 0);

    assert(checked.0);

    (checked.1, checked.2, BLOCKS_AMOUNT - BLOCKS_OFFSET, checked.3)
}

use block::get_block_hash;
use target::check_target;

pub mod block;
pub mod convert;
pub mod target;

fn main() {
    let block = block::BlockHeader {
        version: 1,
        prev_block: "00000000b873e79784647a6c82962c70d228557d24a747ea4d1b8bbe878e1206",
        merkle_root: "20222eb90f5895556926c112bb5aa0df4ab5abc3107e21a6950aec3b2e3541e2",
        timestamp: 1296688946,
        bits: 486604799,
        nonce: 875942400,
    };

    assert(
        get_block_hash(block) == "000000006c02c8ea6e4ff69651f7fcde348fb9d557a06e6957b65552002a7820",
    );

    assert(check_target(block));
}

use bignum::{BigNumTrait, fields::U256::U256};
use block::{BlockHeader, get_block_hash};
use chain::{check_chain, cut};
use std::ops::Mul;
use target::lt;

pub mod block;
pub mod convert;
pub mod target;
pub mod chain;

fn main(blocks: [BlockHeader; 150], last_block_hash: pub str<64>) -> pub bool {
    assert(get_block_hash(blocks[blocks.len() - 1]) == last_block_hash);
    check_chain(blocks)
}

#[test]
fn test() {
    let actual_time = (1458291885 - 1457133956);
    let expected_time = 1209600;

    let max_target = U256::from(
        0x00000000FFFF0000000000000000000000000000000000000000000000000000,
    );

    let targ = U256::from(
        0x000000000000000006f0a8000000000000000000000000000000000000000000,
    );
    let mut target = targ.mul(U256::from(actual_time as Field)).udiv(U256::from(expected_time));

    if lt(
        target.get_limbs_slice(),
        targ.udiv(U256::from(4)).get_limbs_slice(),
    ) {
        target = targ.udiv(U256::from(4));
    } else if lt(
        targ.mul(U256::from(4)).get_limbs_slice(),
        target.get_limbs_slice(),
    ) {
        target = targ.mul(U256::from(4));
    }

    target = if lt(max_target.get_limbs_slice(), target.get_limbs_slice()) {
        max_target
    } else {
        target
    };

    // Safety:
    target = unsafe { cut(target) };

    assert(
        target
            == U256::from(
                0x000000000000000006a4c3000000000000000000000000000000000000000000,
            ),
    );
}

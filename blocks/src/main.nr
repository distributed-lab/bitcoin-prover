use bignum::{BigNumTrait, fields::U256::U256};
use block::BlockHeader;
use chain::{check_chain, cut};
use std::ops::Mul;
use target::lt;

pub mod block;
pub mod convert;
pub mod target;
pub mod chain;

fn main(blocks: [BlockHeader; 150]) -> pub bool {
    check_chain(blocks)
}

#[test]
fn test() {
    // We use many
    let actual_time = (1458291885 - 1457133956) as u64 * 10000000000;
    let expected_time = 2016 * 10 * 60;
    let mut ratio = actual_time / expected_time;
    if ratio < 2500000000 {
        ratio = 2500000000;
    } else if ratio > 40000000000 {
        ratio = 40000000000;
    }

    let max_target = U256::from(
        0x00000000FFFF0000000000000000000000000000000000000000000000000000,
    );
    let mut target = U256::from(
        0x000000000000000006f0a8000000000000000000000000000000000000000000,
    )
        .mul(U256::from(ratio as Field))
        .udiv(U256::from(10000000000));

    target = if lt(max_target.get_limbs_slice(), target.get_limbs_slice()) {
        max_target
    } else {
        target
    };

    target = unsafe { cut(target) };

    assert(
        U256::from(
            0x000000000000000006a4c3000000000000000000000000000000000000000000,
        )
            == target,
    );
}

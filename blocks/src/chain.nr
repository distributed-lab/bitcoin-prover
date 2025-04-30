use super::{block::{BlockHeader, get_block_hash}, target::{check_target, lt, uncompres_target}};
use dep::bignum::{BigNumTrait, U256};
use std::ops::{Div, Mul};

pub(crate) fn check_chain<let SIZE: u32>(blocks: [BlockHeader; SIZE]) -> bool {
    let mut is_correct = true;
    let mut median_timestamp = blocks[0].timestamp as i64;
    let mut prev_bits = blocks[0].bits;

    // without genesis block
    for i in 1..SIZE {
        // prev
        if blocks[i].prev_block != get_block_hash(blocks[i - 1]) {
            is_correct = false;
            println("prev hash fail");
        }

        // timestamp
        if !(blocks[i].timestamp as i64 > median_timestamp) {
            is_correct = false;
            println("timestamp fail");
        }

        // if new target
        if i % 2016 == 0 {
            if prev_bits == blocks[i].bits {
                is_correct = false;
                println("new bits fail");
            } else {
                let actual_time =
                    (blocks[i - 1].timestamp - blocks[i - 2016].timestamp) * 10000000000;
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

                let mut target = uncompres_target(blocks[i - 1].bits)
                    .mul(U256::from(ratio as Field))
                    .div(U256::from(10000000000));

                target = if lt(max_target.get_limbs_slice(), target.get_limbs_slice()) {
                    max_target
                } else {
                    target
                };

                // Safety:
                target = unsafe { cut(target) };

                assert(target == uncompres_target(blocks[i].bits));

                if target != uncompres_target(blocks[i].bits) {
                    is_correct = false;
                    println("target eq fail");
                }
            }
        } else {
            if prev_bits != blocks[i].bits {
                is_correct = false;
                println("prev bits fail");
            }
        }

        // hash < target
        if !check_target(blocks[i]) {
            is_correct = false;
            println("target check fail");
        }

        // new timestamp
        if i > 10 {
            median_timestamp = median_timestamp
                - (blocks[i - 11].timestamp as i64 - blocks[i].timestamp as i64) / 11;
        } else {
            median_timestamp =
                (median_timestamp * i as i64 + blocks[i].timestamp as i64) / (i + 1) as i64;
        }
    }

    is_correct
}

pub(crate) unconstrained fn cut(value: U256) -> U256 {
    let mut res = value;
    let mut count = 0;
    loop {
        if res.udiv(U256::from(2.pow_32(24))).is_zero() {
            break;
        }

        res = res.udiv(U256::from(2.pow_32(8)));
        count += 1;
    }

    res.mul(U256::from(2.pow_32(count * 8)))
}

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
        if (i + 1) % 2016 == 0 {
            if prev_bits == blocks[i].bits {
                is_correct = false;
                println("new bits fail");
            } else {
                // * 100 - noir desn't have float, we will use integers which have 2 nums after , like 2 last nums
                let actual_time = (blocks[i].timestamp - blocks[i - 2015].timestamp) * 100;
                let expected_time = 2016 * 10 * 60 * 100;
                let mut ratio = actual_time / expected_time;
                if ratio < 25 {
                    ratio = 25;
                } else if ratio > 400 {
                    ratio = 400;
                }

                let max_target = U256::from(
                    0x00000000FFFF0000000000000000000000000000000000000000000000000000,
                );
                let unc_targ = uncompres_target(blocks[i].bits);
                let mut target = unc_targ.mul(U256::from(ratio as Field)).div(U256::from(100));

                target = if lt(max_target.get_limbs_slice(), target.get_limbs_slice()) {
                    target
                } else {
                    max_target
                };

                target = bitwise_and_U256(target.get_limbs_slice(), max_target.get_limbs_slice());

                if target != unc_targ {
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

fn bitwise_and_U256(val1: [u128], val2: [u128]) -> U256 {
    U256::from_slice([val1[0] & val2[0], val1[1] & val2[1], val1[2] & val2[2]])
}

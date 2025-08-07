use super::{block::{BlockHeader, get_block_hash}, target::{check_target, uncompres_target}};
use dep::bignum::{BigNum, U256};
use std::ops::Mul;

global expected_time: Field = 1209600;
global max_target: Field = 0x00000000FFFF0000000000000000000000000000000000000000000000000000;

pub fn check_chain<let SIZE: u32>(
    blocks: [BlockHeader; SIZE],
    mut median_timestamp: i64,
    mut prev_bits: u32,
) -> (bool, i64) {
    let mut is_correct = true;

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
            let actual_time = (blocks[i - 1].timestamp - blocks[i - 2016].timestamp);

            let targ = uncompres_target(blocks[i - 1].bits);
            let mut target =
                targ.mul(U256::from((actual_time) as Field)).udiv(U256::from(expected_time));

            if target < targ.udiv(U256::from(4)) {
                target = targ.udiv(U256::from(4));
            } else if targ.mul(U256::from(4)) < target {
                target = targ.mul(U256::from(4));
            }

            target = if U256::from(max_target) < target {
                U256::from(max_target)
            } else {
                // Safety: the target will be cut using shift and compared to the res
                let (res, shift) = unsafe { cut(target) };

                assert(
                    target.udiv(U256::from(2.pow_32(shift as Field))).mul(U256::from(2.pow_32(
                        shift as Field,
                    )))
                        == res,
                );

                res
            };

            if target != uncompres_target(blocks[i].bits) {
                is_correct = false;
                println("target eq fail");
            }

            prev_bits = blocks[i].bits;
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

    (is_correct, median_timestamp)
}

pub(crate) unconstrained fn cut(mut value: U256) -> (U256, u8) {
    let mut count: u8 = 0;
    for _ in 0..256 {
        if value.udiv(U256::from(2.pow_32(24))).is_zero() {
            break;
        }

        value = value.udiv(U256::from(2.pow_32(8)));
        count += 8;
    }

    if U256::from(7) < value.udiv(U256::from(2.pow_32(20))) {
        value = value.udiv(U256::from(2.pow_32(8)));
        count += 8;
    }

    (value.mul(U256::from(2.pow_32(count as Field))), count)
}

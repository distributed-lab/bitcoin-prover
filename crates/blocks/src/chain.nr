use super::{block::{BlockHeader, get_block_hash}, target::{check_target, uncompres_target}};
use dep::bignum::{BigNum, U256, U512};
use std::ops::Mul;

global expected_time: Field = 1209600;
global max_target: Field = 0x00000000FFFF0000000000000000000000000000000000000000000000000000;
global chunk_size: u32 = 1024;

// Returns (is_successful, timestamps, chainwork)
pub fn check_chain<let SIZE: u32>(
    blocks: [BlockHeader; SIZE],
    mut timestamps: [u32; 11],
    mut time_idx: u32,
    mut prev_bits: u32,
    mut block_height: u32,
    mut chainwork: Field,
    mut prev_timestamp: u32,
) -> (bool, [u32; 11], u32, u32, Field, u32) {
    let mut is_correct = true;
    let first_batch = block_height == 0;
    let old_targ = prev_bits;
    let mut targets = [(0, 0); SIZE / chunk_size + 1];
    let mut targets_idx = 0;
    if (block_height + 1) % 2016 != 0 {
        targets[targets_idx].1 = old_targ;
    } else {
        targets_idx -= 1;
    }

    for i in 1..SIZE {
        block_height += 1;
        // prev block hash
        if blocks[i].prev_block != get_block_hash(blocks[i - 1]) {
            is_correct = false;
            println("prev hash fail");
        }

        let idx = if first_batch & (i < 11) {
            i / 2 + 11 - i
        } else {
            5
        };

        // timestamp
        if !(blocks[i].timestamp > timestamps.sort()[idx]) {
            is_correct = false;
            println("timestamp fail");
        }

        timestamps[time_idx] = blocks[i].timestamp;
        time_idx = (time_idx + 1) % 11;

        // if new target
        if block_height % 2016 == 0 {
            targets_idx += 1;
            targets[targets_idx].1 = blocks[i].bits;
            let actual_time = (blocks[i - 1].timestamp - prev_timestamp);

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
            prev_timestamp = blocks[i].timestamp;
            prev_bits = blocks[i].bits;
        } else {
            if prev_bits != blocks[i].bits {
                is_correct = false;
                println("prev bits fail");
            }
        }

        targets[targets_idx].0 += 1;

        // hash <= target
        if !check_target(blocks[i]) {
            is_correct = false;
            println("target check fail");
        }
    }

    let new_chainwork = calc_chainwork(chainwork, targets);

    (is_correct, timestamps, time_idx, block_height, new_chainwork, prev_timestamp)
}

fn calc_chainwork<let TARG_LEN: u32>(
    mut old_chainwork: Field,
    targets: [(u32, u32); TARG_LEN],
) -> Field {
    let two_pow = U512::from_be_bytes([
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00,
    ]);

    for i in 0..TARG_LEN {
        if targets[i].0 != 0 {
            let work = Field::from_be_bytes(two_pow
                .udiv(U512::from_be_bytes([0; 32]
                    .as_slice()
                    .append(uncompres_target(targets[i].1).to_be_bytes())
                    .as_array::<65>()))
                .to_be_bytes());

            old_chainwork += work * targets[i].0 as Field;
        }
    }

    old_chainwork
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

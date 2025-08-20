use super::{block::{BlockHeader, get_block_hash}, target::{check_target, uncompres_target}};
use dep::bignum::{BigNum, U256, U512};
use std::ops::Mul;

global expected_time: Field = 1209600;
global max_target: Field = 0x00000000FFFF0000000000000000000000000000000000000000000000000000;

// Returns (is_successful, timestamps, chainwork)
pub fn check_chain<let SIZE: u32>(
    blocks: [BlockHeader; SIZE],
    mut timestamps: [u32; 11],
    mut time_idx: u32,
    mut prev_bits: u32,
    mut block_height: u32,
    mut chainwork: Field,
) -> (bool, [u32; 11], u32, u32, Field) {
    let mut is_correct = true;
    let first_batch = block_height == 0;
    let old_targ = prev_bits;

    // skip blocks that were checked before
    for i in 1..SIZE {
        block_height += 1;
        // prev
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
    }

    let new_chainwork = calc_chainwork::<SIZE>(
        chainwork,
        uncompres_target(old_targ),
        uncompres_target(blocks[SIZE - 1].bits),
        block_height,
    );

    (is_correct, timestamps, time_idx, block_height, new_chainwork)
}

fn calc_chainwork<let SIZE: u32>(
    old_chainwork: Field,
    prev_bloks_target: U256,
    cur_blocks_target: U256,
    block_height: u32,
) -> Field {
    let two_pow = U512::from_be_bytes([
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00,
    ]);

    let old_work = Field::from_be_bytes(two_pow
        .udiv(U512::from_be_bytes([0; 32]
            .as_slice()
            .append(prev_bloks_target.to_be_bytes())
            .as_array::<65>()))
        .to_be_bytes());

    let new_work = Field::from_be_bytes(two_pow
        .udiv(U512::from_be_bytes([0; 32]
            .as_slice()
            .append(cur_blocks_target.to_be_bytes())
            .as_array::<65>()))
        .to_be_bytes());

    let new_amount = block_height % 2016 + 1;

    old_chainwork
        + if old_work == new_work {
            old_work * (SIZE - 1) as Field
        } else {
            (new_work * new_amount as Field) + (old_work * (SIZE - new_amount - 1) as Field)
        }
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

#[test]
fn calc_chainwork_test() {
    let target = uncompres_target(0x1d00ffff);
    assert(calc_chainwork::<1025>(0x40104010401, target, target, 2048) == 0x80108010801);
}

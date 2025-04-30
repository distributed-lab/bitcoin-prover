use super::{
    block::{BlockHeader, get_block_hash},
    convert::{reverse_bytes, sha256_to_le_bytes, u32_to_be_bytes},
};
use dep::bignum::{BigNumTrait, U256};
use std::ops::Mul;

pub(crate) fn lt(val1: [u128], val2: [u128]) -> bool {
    if val2[1] > val1[1] {
        true
    } else if val1[1] == val2[1] {
        if val2[0] > val1[0] {
            true
        } else {
            false
        }
    } else {
        false
    }
}

pub(crate) fn check_target(block: BlockHeader) -> bool {
    let hash = reverse_bytes(sha256_to_le_bytes(get_block_hash(block)));
    let sha256_value = U256::from_slice(hash_as_u128_slice(hash));
    lt(
        sha256_value.get_limbs_slice(),
        uncompres_target(block.bits).get_limbs_slice(),
    )
}

fn hash_as_u128_slice(value: [u8; 32]) -> [u128] {
    let mut res = [0; 3].as_slice();

    for i in 0..16 {
        res[0] += (value[i + 16] as u128) << ((15 - i) * 8);
        res[1] += (value[i] as u128) << ((15 - i) * 8);
    }

    res
}

pub(crate) fn uncompres_target(value: u32) -> U256 {
    let bytes = u32_to_be_bytes(value);
    let exp = bytes[0] as Field;
    let mantissa = U256::from_slice([
        (bytes[1] as u128 << 16) + (bytes[2] as u128 << 8) + bytes[3] as u128,
        0,
        0,
    ]);
    let mul = 256.pow_32(exp - 3);
    mantissa.mul(U256::from(mul))
}

use dep::bignum::{BigNumTrait, U256};
use std::ops::Mul;

global base58: [u8; 58] = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".as_bytes();

pub(crate) fn get_address<let LEN: u32>(ripemd: [u8; 20]) -> str<LEN> {
    let mut res = [0; LEN];
    let mut bytes = [5; 1].as_slice();
    bytes = bytes.append(ripemd);
    let checksum = sha256::digest(sha256::digest(bytes.as_array::<21>()));
    for i in 0..4 {
        bytes = bytes.push_back(checksum[i]);
    }

    let divider = U256::from(58);
    let mut divided = U256::from_slice(as_u128_slice(bytes.as_array::<25>()));

    let mut quotient = U256::zero();
    let mut remainder = U256::zero();

    for i in 0..LEN {
        quotient = divided.udiv(divider);
        remainder = divided - quotient.mul(divider);
        res[LEN - i - 1] = base58[remainder.get_limb(0)];

        divided = quotient;
    }

    res.as_str_unchecked()
}

fn as_u128_slice(value: [u8; 25]) -> [u128] {
    let mut res = [0; 3].as_slice();

    for i in 0..15 {
        res[0] += (value[24 - i] as u128) << ((i) * 8);
    }

    for i in 0..10 {
        res[1] += (value[9 - i] as u128) << ((i) * 8);
    }

    res
}

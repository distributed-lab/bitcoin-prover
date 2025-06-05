use dep::bignum::{BigNum, U256};
use ripemd160::ripemd160;
use std::ops::Mul;

global base58: [u8; 58] = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz".as_bytes();

pub fn check_script<let LEN: u32, let ADR: u32>(script: str<LEN>, addr: str<ADR>) -> bool {
    let script = script_to_bytes(script);
    let hash = ripemd160::<32>(sha256::digest(script));

    get_address::<ADR>(hash) == addr
}

pub fn script_to_bytes<let LEN: u32>(script: str<LEN>) -> [u8; LEN / 2] {
    let raw_bytes = script.as_bytes();
    let mut res = [0; LEN / 2];

    for i in 0..(LEN / 2) {
        res[i] = (hex_symbol_to_byte(raw_bytes[i * 2]) * 16)
            + hex_symbol_to_byte(raw_bytes[(i * 2) + 1]);
    }

    res
}

fn hex_symbol_to_byte(value: u8) -> u8 {
    if value < 58 {
        value - 48
    } else {
        value - 87
    }
}

fn get_address<let LEN: u32>(ripemd: [u8; 20]) -> str<LEN> {
    let mut res = [0; LEN];
    let mut bytes = [5; 1].as_slice();
    bytes = bytes.append(ripemd);
    let checksum = sha256::digest(sha256::digest(bytes.as_array::<21>()));
    for i in 0..4 {
        bytes = bytes.push_back(checksum[i]);
    }

    let divider = U256::from(58);
    let mut divided = U256::from_be_bytes([0; 8].as_slice().append(bytes).as_array::<33>());

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

#[test]
fn test_base58() {
    assert(get_address::<34>([0; 20]) == "31h1vYVSYuKP6AhS86fbRdMw9XHieotbST");

    assert(
        get_address::<34>([
            184, 144, 114, 199, 223, 158, 97, 157, 0, 164, 89, 62, 138, 251, 161, 231, 184, 186, 30,
            168,
        ])
            == "3JWuJHhVg3s84J2JfMcA59doNqdCFvH6jb",
    );

    assert(
        get_address::<34>([
            216, 5, 100, 220, 11, 49, 60, 93, 156, 161, 35, 216, 193, 131, 186, 222, 82, 255, 17,
            65,
        ])
            == "3MPELm1Zt83sMD63zBDUioX4AY6W4nFB1q",
    );
}

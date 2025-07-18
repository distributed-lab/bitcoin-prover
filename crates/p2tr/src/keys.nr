use dep::bignum::{BigNum, U256, U768};
use crypto::{point::{add_point, mul_point, Point}, types::{I768, sqrt_secp256k1}};
use std::ops::{Add, Mul};
use utils::convert::{get_256_bits_from_768, hex_to_bytes};
use dep::bignum::fields::{secp256k1Fq::Secp256k1_Fq, secp256k1Fr::Secp256k1_Fr};

pub fn get_tweaked_pub_key(pub_key: Point, merkle_root: [u8; 32]) -> Secp256k1_Fq {
    let stringHash = sha256::digest("TapTweak".as_bytes());
    let dstringHash = stringHash.as_slice().append(stringHash).as_array::<64>();

    let tweak = sha256::digest(dstringHash
        .as_slice()
        .append(pub_key.x.to_be_bytes())
        .append(merkle_root)
        .as_array::<128>());

    // Base point
    let G = Point {
        x: Secp256k1_Fq::from_be_bytes(
            [
                0x79, 0xBE, 0x66, 0x7E, 0xF9,
                0xDC, 0xBB, 0xAC, 0x55, 0xA0, 0x62, 0x95, 0xCE, 0x87, 0x0B, 0x07, 0x02, 0x9B, 0xFC,
                0xDB, 0x2D, 0xCE, 0x28, 0xD9, 0x59, 0xF2, 0x81, 0x5B, 0x16, 0xF8, 0x17, 0x98,
            ]
        ),
        y: Secp256k1_Fq::from_be_bytes( 
            [
                0x48, 0x3A, 0xDA, 0x77, 0x26,
                0xA3, 0xC4, 0x65, 0x5D, 0xA4, 0xFB, 0xFC, 0x0E, 0x11, 0x08, 0xA8, 0xFD, 0x17, 0xB4,
                0x48, 0xA6, 0x85, 0x54, 0x19, 0x9C, 0x47, 0xD0, 0x8F, 0xFB, 0x10, 0xD4, 0xB8,
            ]
        ),
        is_O: false,
    };

    let mut tweak_point = mul_point(
        Secp256k1_Fr::from_be_bytes(tweak),
        G,
    );

    add_point(pub_key, tweak_point).x
}

#[test]
fn get_tweaked_pub_key_test() {
    // Tweaked pub key
    // a2fc329a085d8cfc4fa28795993d7b666cee024e94c40115141b8e9be4a29fa4
    let pub_x = Secp256k1_Fq::from_be_bytes(
        [
            0xa2, 0xfc, 0x32, 0x9a, 0x08,
            0x5d, 0x8c, 0xfc, 0x4f, 0xa2, 0x87, 0x95, 0x99, 0x3d, 0x7b, 0x66, 0x6c, 0xee, 0x02,
            0x4e, 0x94, 0xc4, 0x01, 0x15, 0x14, 0x1b, 0x8e, 0x9b, 0xe4, 0xa2, 0x9f, 0xa4,
        ]
    );

    // y^2 = x^3 + 7
    let pub_y = sqrt_secp256k1(pub_x * pub_x * pub_x + Secp256k1_Fq::from(7));

    let pub_key_point = Point { x: pub_x, y: pub_y, is_O: false };

    assert(
        get_tweaked_pub_key(
            pub_key_point,
            hex_to_bytes(
                "b5b72eea07b3e338962944a752a98772bbe1f1b6550e6fb6ab8c6e6adb152e7c",
            ),
        )
            == Secp256k1_Fq::from_be_bytes([
                0x56, 0x25, 0x29, 0x04, 0x7f, 0x47, 0x6b, 0x9a, 0x83, 0x3a, 0x5a, 0x78, 0x0a,
                0x75, 0x84, 0x5e, 0xc3, 0x29, 0x80, 0x33, 0x0d, 0x76, 0xd1, 0xac, 0x9f, 0x35, 0x1d,
                0xc7, 0x6b, 0xce, 0x5d, 0x72,
            ]),
    );
}

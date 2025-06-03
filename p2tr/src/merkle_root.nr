use dep::bignum::{BigNum, U256};

// pub(crate) fn get_mercle_root<let N: u32>(scripts: [[u8; 32]; N]) -> [u8; 32] {
//     let mut scrs = scripts.as_slice();
//     // Safety: it will be cheked
//     let mut iter = unsafe { log2(N) };

//     let mut pow = 2;
//     for _ in 0..(iter - 1) {
//         pow *= 2;
//     }
//     let more = pow * 2;

//     assert(pow <= N & more > N);

//     if (pow != N) {
//         iter += 1;
//     }

//     for _ in 0..iter {
//         let mut tmp = [[0; 32]; 0].as_slice();
//         for i in 0..(scrs.len() / 2 + scrs.len() % 2) {
//             if (i == (scrs.len() / 2 + scrs.len() % 2) - 1) & (scrs.len() % 2 == 1) {
//                 tmp = tmp.push_back(scrs[i * 2]);
//             }
//             else {
//                 tmp = tmp.push_back(get_branch(scrs[i * 2], scrs[i * 2 + 1]));
//             }
//         }
//         scrs = tmp;
//     }

//     scrs[0]
// }

pub(crate) fn get_branch(leaf1: [u8; 32], leaf2: [u8; 32]) -> [u8; 32] {
    let concat: [u8; 64] = if (
        U256::from_be_bytes(leaf1.as_slice().push_front(0).as_array())
            < U256::from_be_bytes(leaf2.as_slice().push_front(0).as_array())
    ) {
        leaf1.as_slice().append(leaf2).as_array()
    } else {
        leaf2.as_slice().append(leaf1).as_array()
    };

    let stringHash = sha256::digest("TapBranch".as_bytes());
    let dstringHash = stringHash.as_slice().append(stringHash).as_array::<64>();

    sha256::digest(dstringHash.as_slice().append(concat).as_array::<128>())
}

pub(crate) fn hash_from_script<let N: u32>(script: str<N>) -> [u8; 32] {
    // SHA256( SHA256(string) || SHA256(string) || data )
    let stringHash = sha256::digest("TapLeaf".as_bytes());
    let dstringHash = stringHash.as_slice().append(stringHash).as_array::<64>();
    if N < 253 {
        sha256::digest::<66 + N / 2>(dstringHash
            .as_slice()
            .append([192].as_slice().push_back((N / 2) as u8).append(script_to_bytes(script)))
            .as_array())
    } else if N < 65536 {
        sha256::digest::<68 + N / 2>(dstringHash
            .as_slice()
            .append([192]
                .as_slice()
                .push_back(253)
                .append(((N / 2) as Field).to_le_bytes::<2>())
                .append(script_to_bytes(script)))
            .as_array())
    } else if N < 4294967296 {
        sha256::digest::<70 + N / 2>(dstringHash
            .as_slice()
            .append([192]
                .as_slice()
                .push_back(254)
                .append(((N / 2) as Field).to_le_bytes::<4>())
                .append(script_to_bytes(script)))
            .as_array())
    } else {
        sha256::digest::<74 + N / 2>(dstringHash
            .as_slice()
            .append([192]
                .as_slice()
                .push_back(255)
                .append(((N / 2) as Field).to_le_bytes::<8>())
                .append(script_to_bytes(script)))
            .as_array())
    }
}

fn script_to_bytes<let LEN: u32>(script: str<LEN>) -> [u8; LEN / 2] {
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

// unconstrained fn log2(value: u32) -> u32 {
//     let mut log = 2;
//     loop {
//         let mut val = 2;
//         for _ in 0..(log - 1) {
//             val *= 2;
//         }

//         if (val > value) {
//             break;
//         }

//         log += 1;
//     }

//     log - 1
// }

#[test]
fn script_hash_test() {
    let mut script1 = "5187";
    assert(
        hash_from_script(script1)
            == [
                0x6b, 0x13, 0xbe, 0xcd, 0xaf, 0x0e, 0xee, 0x49, 0x7e, 0x2f, 0x30, 0x4a, 0xdc, 0xfa,
                0x1c, 0x0c, 0x9e, 0x84, 0x56, 0x1c, 0x99, 0x89, 0xb7, 0xf2, 0xb5, 0xfc, 0x39, 0xf5,
                0xf9, 0x0a, 0x60, 0xf6,
            ],
    );

    let script2 = "7ac458a397826e4e6bec35c43548f8a9c39c3b29eb97c185e4555b55f82fc83c35f8a64865c0f9fdb42a64541690dd28a83dc85db1052ded4ddb0fee704ded8c044f508f1bec090c10cd47c8033931f90e4990473044015c245aff7db7d22d44";
    assert(
        hash_from_script(script2)
            == [
                0x3d, 0xb7, 0xa2, 0xcc, 0x47, 0x7e, 0xee, 0x71, 0xe1, 0x56, 0x73, 0x24, 0xe5, 0x09,
                0x84, 0xbb, 0x25, 0xdb, 0x00, 0x74, 0x84, 0x6d, 0x4c, 0xbd, 0xa1, 0x19, 0xf9, 0x34,
                0x56, 0x10, 0x63, 0xf6,
            ],
    );
}

#[test]
fn get_branch_test() {
    let mut script1 = "5187";
    let script2 = "7ac458a397826e4e6bec35c43548f8a9c39c3b29eb97c185e4555b55f82fc83c35f8a64865c0f9fdb42a64541690dd28a83dc85db1052ded4ddb0fee704ded8c044f508f1bec090c10cd47c8033931f90e4990473044015c245aff7db7d22d44";

    println(
        get_branch(hash_from_script(script1), hash_from_script(script2)),
    );

    assert(
        get_branch(hash_from_script(script1), hash_from_script(script2))
            == [
                0x37, 0xf6, 0x42, 0x65, 0xc2, 0xa8, 0x89, 0xac, 0x15, 0xf3, 0xd3, 0xfb, 0xdb, 0x03,
                0x4c, 0x9e, 0x8c, 0xfb, 0xff, 0x7b, 0xb1, 0x27, 0xe8, 0xae, 0xd5, 0x6a, 0x32, 0x5a,
                0x31, 0x11, 0xcf, 0x66,
            ],
    );
}

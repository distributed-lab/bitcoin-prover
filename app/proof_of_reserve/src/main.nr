mod constants;

use trees::merkle::{MerkleTree, MT_Creator, Modifier, MembershipProver};

use constants::{CONST_STRING_LEN, COINS_DATABASE_AMOUNT, MAX_USER_UTXOS_AMOUNT};

// p2pkh
struct COINS_DATABASE_ELEMENT {
    script_pub_key: [u8; 25],
    amount: u64,
}

struct UTXO {
    index: u64,
    script_sig: [u8; 140],
}

fn main(
    // merkle_root: pub [u8; 32],
    // const_string: pub str<CONST_STRING_LEN>,
    // coins_database: [COINS_DATABASE_ELEMENT; COINS_DATABASE_AMOUNT],
    // own_utxo: [UTXO; MAX_USER_UTXOS_AMOUNT],
) -> pub Field {
    //println(merkle_root([[0; 32], [1; 32], [2; 32]]));
    let mut mt = MerkleTree::new(hasher);
    let paths= [];

    mt.add([0; 32], 0, paths);
    let mut paths = paths.concat([mt.root]);
    mt.add([1; 32], 1, paths);
    paths[0] = mt.root;
    mt.add([3; 32], 0, []);
    mt.add([4; 32], 1, paths);


    mt.membership([0; 32], 0, [[1; 32], [3; 32]]);
    println(mt.root);
    0
}

fn hasher(leaves: [[u8; 32]; 2]) -> [u8; 32] {
    sha256::digest(leaves[0].as_slice().append(leaves[1]).as_array::<64>())
}

fn merkle_root<let N: u32>(leafs: [[u8; 32]; N]) -> [u8; 32] {
    let mut mt = MerkleTree::new(hasher);
    let paths= [];

    let mut level_change = 0;
    let mut to_level = 2;

    for i in 0..N {
        mt.add(leafs[i], i as Field, paths);
        let paths = paths.concat([mt.root]);
    }

    mt.root
}

// fn hash(leaf1: [u8; 32], leaf2: [u8; 32]) -> [u8; 32] {
//     sha256::digest(leaf1.as_slice().append(leaf2).as_array::<64>())
// }

// fn merkle_root<let N: u32>(mut leafs: [[u8; 32]; N]) -> [u8; 32] {
//     for i in 0..(N/2) {
//         leafs[i] = hash(leafs[2*i], leafs[2*i+1]);
//     }

//     leafs[0]
// }

mod constants;

use trees::merkle::{MerkleTree, MT_Creator, Modifier, MembershipProver};

use constants::{CONST_STRING_LEN, COINS_DATABASE_AMOUNT, MAX_USER_UTXOS_AMOUNT, MAX_MERKLE_TREE_LEVELS};
use std::cmp::max;

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
    println(merkle_root([[2; 32], [3; 32]]));

    0
}

// fn hasher(leaves: [[u8; 32]; 2]) -> [u8; 32] {
//     sha256::digest(leaves[0].as_slice().append(leaves[1]).as_array::<64>())
// }

// fn merkle_root<let N: u32>(leafs: [[u8; 32]; N]) -> [u8; 32] {
//     let mut mt = MerkleTree::new(hasher);
//     let paths= [];

//     let mut level_change = 0;
//     let mut to_level = 2;

//     for i in 0..N {
//         mt.add(leafs[i], i as Field, paths);
//         let paths = paths.concat([mt.root]);
//     }

//     mt.root
// }

fn hash(leaf1: [u8; 32], leaf2: [u8; 32]) -> [u8; 32] {
    sha256::digest(leaf1.as_slice().append(leaf2).as_array::<64>())
}

fn merkle_root<let N: u32>(mut leafs: [[u8; 32]; N]) -> [u8; 32] {
    // !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    assert((N as Field).lt(2.pow_32(MAX_MERKLE_TREE_LEVELS as Field)));
    let mut mtree = [[0; 32]; MAX_MERKLE_TREE_LEVELS];
    let mut last_level = 0;

    for i in 0..N {
        let mut leaf = leafs[i];
        for j in 0..MAX_MERKLE_TREE_LEVELS {
            if !leaf.all(|e| e == 0) {
                if mtree[j].all(|e| e == 0) {
                    mtree[j] = leaf;
                    leaf = [0; 32];
                }
                else {
                    leaf = hash(leaf, mtree[j]);
                    mtree[j] = [0; 32];
                }
                last_level = max(j, last_level);
            }
        }
    }

    let mut tmp_node = [0; 32];
    for i in 0..MAX_MERKLE_TREE_LEVELS {
        if ((i < last_level & tmp_node.all(|e| e == 0)) | (i <= last_level & !tmp_node.all(|e| e == 0))) {
            if !mtree[i].all(|e| e == 0) {
                let right = if tmp_node.all(|e| e == 0) {
                    mtree[i]
                } else {
                    tmp_node
                };

                tmp_node = hash(mtree[i], right);
                mtree[i] = [0; 32];
            } else if !tmp_node.all(|e| e == 0) {
                tmp_node = hash(tmp_node, tmp_node);
            }
        }
    }

    if tmp_node.all(|e| e == 0) {
        mtree[last_level]
    } else {
        tmp_node
    }
}

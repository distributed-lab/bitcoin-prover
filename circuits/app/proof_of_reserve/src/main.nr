mod constants;

use constants::{MAX_COINS_DATABASE_AMOUNT, MAX_MERKLE_TREE_LEVELS, MAX_USER_UTXOS_AMOUNT};
use std::cmp::max;
use trees::merkle::{MerkleTree, Modifier, MT_Creator};
use utils::convert::u64_to_be_bytes;

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
    //const_message: pub [u8; 32],
    coins_database: [COINS_DATABASE_ELEMENT; MAX_COINS_DATABASE_AMOUNT],
    //own_utxo: [UTXO; MAX_USER_UTXOS_AMOUNT],
) -> pub ([u8; 32], Field) {
    let mut utxos = [[0; 32]; MAX_COINS_DATABASE_AMOUNT];

    for i in 0..MAX_COINS_DATABASE_AMOUNT {
        // There is a bug with append, so we fill the array manually
        let mut utx_bytes = [0; 33];

        let amount_bytes = u64_to_be_bytes(coins_database[i].amount);
        for j in 0..8 {
            utx_bytes[j] = amount_bytes[j];
        }

        for j in 0..25 {
            utx_bytes[j + 8] = coins_database[i].script_pub_key[j];
        }

        utxos[i] = if coins_database[i].amount != 0 {
            sha256::digest(utx_bytes)
        } else {
            [0; 32]
        };
    }

    (merkle_root(utxos), 0)
}

// fn hasher(leaves: [[u8; 32]; 2]) -> [u8; 32] {
//     hash(leaves[0], leaves[1])
// }

// fn merkle_root_lib<let N: u32>(mut leafs: [[u8; 32]; N]) -> [u8; 32] {
//     let mut mt = MerkleTree::new(hasher);
//     mt.add([1; 32], 0, []);
//     mt.add([2; 32], 1, [[1; 32]]);
//     let root = mt.root;
//     mt.add([3; 32], 1, [root]);
//     mt.add([4; 32], 3, [[3; 32], [248, 24, 175, 211, 122, 109, 195, 188, 146, 251, 68, 115, 16, 17, 39, 112, 6, 219, 78, 250, 110, 144, 35, 205, 116, 104, 192, 35, 53, 210, 42, 77]]);

//     [0; 32]
// }

fn hash(leaf1: [u8; 32], leaf2: [u8; 32]) -> [u8; 32] {
    sha256::digest(leaf1.as_slice().append(leaf2).as_array::<64>())
}

fn merkle_root<let N: u32>(mut leafs: [[u8; 32]; N]) -> [u8; 32] {
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
                } else {
                    leaf = hash(mtree[j], leaf);
                    mtree[j] = [0; 32];
                }
                last_level = max(j, last_level);
            }
        }
    }

    let mut tmp_node = [0; 32];
    for i in 0..MAX_MERKLE_TREE_LEVELS {
        if (
            (i < last_level & tmp_node.all(|e| e == 0))
                | (i <= last_level & !tmp_node.all(|e| e == 0))
        ) {
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

mod constants;

use constants::MAX_MERKLE_TREE_LEVELS;
use std::cmp::max;

fn main() {
    // let mut utxos = [[0; 32]; MAX_COINS_DATABASE_AMOUNT];

    // for i in 0..MAX_COINS_DATABASE_AMOUNT {
    //     // There is a bug with append, so we fill the array manually
    //     let mut utx_bytes = [0; 33];

    //     let amount_bytes = u64_to_be_bytes(coins_database[i].amount);
    //     for j in 0..8 {
    //         utx_bytes[j] = amount_bytes[j];
    //     }

    //     for j in 0..25 {
    //         utx_bytes[j + 8] = coins_database[i].script_pub_key[j];
    //     }

    //     utxos[i] = if coins_database[i].amount != 0 {
    //         sha256::digest(utx_bytes)
    //     } else {
    //         [0; 32]
    //     };
    // }

    // (merkle_root(utxos), 0)
}

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

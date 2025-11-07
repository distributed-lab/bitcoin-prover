use std::cmp::max;

fn hash(leaf1: [u8; 32], leaf2: [u8; 32]) -> [u8; 32] {
    sha256::digest(leaf1.as_slice().append(leaf2).as_array::<64>())
}

pub fn merkle_root<let N: u32, let MAX_MERKLE_TREE_LEVELS: u32>(
    mut leafs: [[u8; 32]; N],
) -> [u8; 32] {
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

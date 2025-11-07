// Third proof
// Build root from many nodes

mod constants;

use constants::{
    HONK_IDENTIFIER, HONK_PROOF_SIZE, HONK_VK_SIZE,
    MAX_MERKLE_TREE_LEVELS, PUBLIC_INPUTS, MAX_NODES_AMOUNT
};
use utils::merkle_root::merkle_root;

struct NodeProof {
    proof: [Field; HONK_PROOF_SIZE],
    public_inputs: [Field; PUBLIC_INPUTS],
}

fn main(
    verification_key: [Field; HONK_VK_SIZE],
    node_proofs: [NodeProof; MAX_NODES_AMOUNT]
) -> pub ([u8; 32], u64) {
    let mut nodes = [[0; 32]; MAX_NODES_AMOUNT];
    let mut owned_amount = 0;

    for i in 0..MAX_NODES_AMOUNT {
        std::verify_proof_with_type(verification_key, node_proofs[i].proof, node_proofs[i].public_inputs, 0x0, HONK_IDENTIFIER);
        for j in 0..32 {
            nodes[i][j] = node_proofs[i].public_inputs[j] as u8;
        }

        owned_amount += node_proofs[i].public_inputs[32] as u64;
    }

    (merkle_root::<MAX_NODES_AMOUNT, MAX_MERKLE_TREE_LEVELS>(nodes), owned_amount)
}

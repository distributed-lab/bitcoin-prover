// Second proof
// Build root from many nodes

mod constants;

use bb_proof_verification::{UltraHonkVerificationKey, UltraHonkZKProof, verify_ultrahonkzk_proof};
use constants::{MAX_MERKLE_TREE_LEVELS, MAX_NODES_AMOUNT, PUBLIC_INPUTS_SIZE, SHA256_HASH_SIZE};
use utils::merkle_root::merkle_root;

struct NodeProof {
    proof: UltraHonkZKProof,
    public_inputs: [Field; PUBLIC_INPUTS_SIZE],
}

fn main(
    verification_key: UltraHonkVerificationKey,
    key_hash: Field,
    node_proofs: [NodeProof; MAX_NODES_AMOUNT],
    finalize_mr: bool,
) -> pub ([u8; SHA256_HASH_SIZE], [u8; SHA256_HASH_SIZE], u64) {
    let mut nodes = [[0; SHA256_HASH_SIZE]; MAX_NODES_AMOUNT];
    let mut owned_amount = 0;

    for i in 0..MAX_NODES_AMOUNT {
        if !node_proofs[i].public_inputs.all(|e| e == 0) {
            verify_ultrahonkzk_proof(
                verification_key,
                node_proofs[i].proof,
                node_proofs[i].public_inputs,
                key_hash,
            );

            for j in 0..SHA256_HASH_SIZE {
                nodes[i][j] = node_proofs[i].public_inputs[j + SHA256_HASH_SIZE] as u8;
            }

            owned_amount += node_proofs[i].public_inputs[64] as u64;
        } else {
            nodes[i] = [0; 32];
        }
    }

    let mut const_message = [0; 32];
    for i in 0..32 {
        const_message[i] = node_proofs[0].public_inputs[i] as u8;
    }

    (
        const_message, merkle_root::<MAX_NODES_AMOUNT, MAX_MERKLE_TREE_LEVELS>(nodes, finalize_mr),
        owned_amount,
    )
}

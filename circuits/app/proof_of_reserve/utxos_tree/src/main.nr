// Second proof
// Build node from one chunk leafs

mod constants;

use constants::{
    HONK_IDENTIFIER, HONK_PROOF_SIZE, HONK_VK_SIZE, MAX_COINS_DATABASE_AMOUNT,
    MAX_MERKLE_TREE_LEVELS, PUBLIC_INPUTS,
};
use utils::merkle_root::merkle_root;

fn main(
    verification_key: [Field; HONK_VK_SIZE],
    proof: [Field; HONK_PROOF_SIZE],
    public_inputs: [Field; PUBLIC_INPUTS],
) -> pub ([u8; 32], u64) {
    std::verify_proof_with_type(verification_key, proof, public_inputs, 0x0, HONK_IDENTIFIER);
    let mut leafs = [[0; 32]; MAX_COINS_DATABASE_AMOUNT];

    for i in 0..MAX_COINS_DATABASE_AMOUNT {
        for j in 0..32 {
            leafs[i][j] = public_inputs[i * 32 + 32 + j] as u8;
        }
    }

    (
        merkle_root::<MAX_COINS_DATABASE_AMOUNT, MAX_MERKLE_TREE_LEVELS>(leafs),
        public_inputs[MAX_COINS_DATABASE_AMOUNT * 32 + 32] as u64,
    )
}

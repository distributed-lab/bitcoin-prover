// First proof
// Checks if user own corresponding utxos and accumulate amount

mod constants;

use constants::{
    MAX_COINS_DATABASE_AMOUNT, MAX_MERKLE_TREE_LEVELS, RIPEMD160_HASH_SIZE, SHA256_HASH_SIZE,
};
use crypto::ecdsa::{
    ecdsa_verify, get_rs_from_signature, get_xy_from_compressed_pubkey,
    get_xy_from_uncompressed_pubkey,
};
use utils::merkle_root::merkle_root;

// p2pkh
struct CoinsDatabaseElement {
    script_pub_key: [u8; 25],
    amount: u64,
}

struct OwnUtxo {
    witness: [u8; 72],
    pub_key: [u8; 65],
}

fn main(
    const_message_hash: pub [u8; SHA256_HASH_SIZE],
    coins_database: [CoinsDatabaseElement; MAX_COINS_DATABASE_AMOUNT],
    own_utxos: [OwnUtxo; MAX_COINS_DATABASE_AMOUNT],
) -> pub ([u8; SHA256_HASH_SIZE], u64) {
    let mut owned_amount = 0;
    let mut coins_hashes = [[0; SHA256_HASH_SIZE]; MAX_COINS_DATABASE_AMOUNT];

    for i in 0..MAX_COINS_DATABASE_AMOUNT {
        if !own_utxos[i].witness.all(|e| e == 0) {
            let signature = get_rs_from_signature(own_utxos[i].witness);
            let mut key_hash = [0; RIPEMD160_HASH_SIZE];

            let (x, y) = if own_utxos[i].pub_key[0] == 4 {
                key_hash = ripemd160::ripemd160(sha256::digest(own_utxos[i].pub_key));
                get_xy_from_uncompressed_pubkey(own_utxos[i].pub_key)
            } else {
                let mut c_key = [0; 33];
                for j in 0..33 {
                    c_key[j] = own_utxos[i].pub_key[j]
                }

                key_hash = ripemd160::ripemd160(sha256::digest(c_key));
                get_xy_from_compressed_pubkey(c_key)
            };

            let mut hash_in_spk = [0; RIPEMD160_HASH_SIZE];
            for j in 0..RIPEMD160_HASH_SIZE {
                hash_in_spk[j] = coins_database[i].script_pub_key[j + 3];
            }

            assert(
                key_hash == hash_in_spk,
                "The specified public key does not match the key in the script_pub_key",
            );

            if ecdsa_verify(x, y, signature, const_message_hash) {
                owned_amount += coins_database[i].amount;
            } else {
                assert(false, f"ECDSA signature check failed on utxo with index {i}");
            }
        }

        let mut utx_bytes = [0; 33];

        let amount_bytes = Field::to_le_bytes::<8>(coins_database[i].amount as Field);
        for j in 0..8 {
            utx_bytes[j] = amount_bytes[j];
        }

        for j in 0..25 {
            utx_bytes[j + 8] = coins_database[i].script_pub_key[j];
        }

        coins_hashes[i] = if coins_database[i].amount != 0 {
            sha256::digest(utx_bytes)
        } else {
            [0; SHA256_HASH_SIZE]
        };
    }

    (merkle_root::<MAX_COINS_DATABASE_AMOUNT, MAX_MERKLE_TREE_LEVELS>(coins_hashes), owned_amount)
}

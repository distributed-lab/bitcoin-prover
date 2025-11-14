use std::{fs::File, io::Write};

use anyhow::Result;
use bitcoin::hashes::{Hash, sha256};
use k256::{ecdsa::SigningKey, elliptic_curve::sec1::ToEncodedPoint};
use sha2::{Digest, Sha256};
use utxo_test_data_generator::test_data_gen::{TestUtxo, generate_test_utxos};

use crate::{
    generate_tomls::leafs_tomls,
    proofs::{prove_leafs, prove_nodes},
};

mod generate_tomls;
mod proofs;

pub const MAX_COINS_DATABASE_AMOUNT: usize = 8;
pub const MAX_NODES_AMOUNT: usize = 8;
pub const MAX_ASYNC_TASKS: usize = 2;

#[tokio::main]
async fn main() {
    let message = "Hello, world!";
    let priv_key = [1; 32];
    let utxos = generate_test_utxos(9, message.as_ref(), &priv_key).unwrap();

    let total_amount: u64 = utxos.iter().map(|u| u.amount).sum();

    let sk = SigningKey::from_bytes(&priv_key).unwrap();
    let pk = sk.verifying_key();

    let message_hash = Sha256::digest(message);
    let pub_key = pk.to_encoded_point(true);

    let rounded_leafs = (utxos.len() + MAX_COINS_DATABASE_AMOUNT - 1) / MAX_COINS_DATABASE_AMOUNT;

    write_consts().unwrap();

    //run first proof
    leafs_tomls(utxos.clone(), message_hash.as_ref(), pub_key.as_bytes()).unwrap();
    prove_leafs(rounded_leafs).await.unwrap();

    // run second proof
    let (mr, amount) = prove_nodes(rounded_leafs).await.unwrap();

    println!("Merkle root: {}, Amount: {}", mr, amount);
    get_merkle_root(utxos);
    println!("Expected amount: {}", total_amount)
}

fn get_merkle_root(utxos: Vec<TestUtxo>) {
    let mut hashes = Vec::new();

    for i in utxos {
        let mut data = i.amount.to_le_bytes().to_vec();
        data.append(&mut hex::decode(i.script_pub_key).unwrap());

        let hash = Sha256::digest(data);
        hashes.push(hash.to_vec());
    }

    let hashes: Vec<sha256::Hash> = hashes
        .into_iter()
        .map(|h| sha256::Hash::from_slice(&h).unwrap())
        .collect();

    let merkle_root = bitcoin::merkle_tree::calculate_root(hashes.iter().cloned()).unwrap();
    println!("Expected merkle root: {merkle_root}");
}

fn write_consts() -> Result<()> {
    let mut file = File::create("../circuits/app/proof_of_reserve/coins/src/constants.nr")?;

    let consts = format!(
        "pub global MAX_COINS_DATABASE_AMOUNT: u32 = {};
pub global MAX_MERKLE_TREE_LEVELS: u32 = {};

pub global SHA256_HASH_SIZE: u32 = 32;
pub global RIPEMD160_HASH_SIZE: u32 = 20;
",
        MAX_COINS_DATABASE_AMOUNT,
        ((MAX_COINS_DATABASE_AMOUNT as f64).log2()).ceil() as u64 + 1
    );

    file.write(consts.as_bytes())?;

    let mut file = File::create("../circuits/app/proof_of_reserve/utxos_tree/src/constants.nr")?;

    let consts = format!(
        "pub global MAX_MERKLE_TREE_LEVELS: u32 = {};
pub global MAX_NODES_AMOUNT: u32 = {};

pub global PUBLIC_INPUTS_SIZE: u32 = 65;

pub global SHA256_HASH_SIZE: u32 = 32;
",
        ((MAX_NODES_AMOUNT as f64).log2()).ceil() as u64 + 1,
        MAX_NODES_AMOUNT
    );

    file.write(consts.as_bytes())?;

    Ok(())
}

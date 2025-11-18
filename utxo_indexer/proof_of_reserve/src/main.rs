use std::{
    collections::HashMap,
    fs::File,
    io::{Read, Write},
};

use anyhow::Result;
use bitcoin::hashes::{Hash, sha256};
use clap::Parser;
use indexer::load_utxos;
use serde::Deserialize;
use sha2::{Digest, Sha256};
use utxo_test_data_generator::test_data_gen::{Utxo, generate_test_utxos};

use crate::{
    generate_tomls::leafs_tomls,
    proofs::{prove_leafs, prove_nodes},
};

mod cli;
mod generate_tomls;
mod proofs;

pub const MAX_COINS_DATABASE_AMOUNT: usize = 8;
pub const MAX_NODES_AMOUNT: usize = 8;
pub const MAX_ASYNC_TASKS: usize = 2;

pub const P2PKH_UTXO_SIZE: usize = 8 + 25; // 8 bytes for amount, 25 bytes for P2PKH scriptPubKey

#[derive(Debug, Deserialize)]
struct OwnItem {
    script_pub_key: String,
    witness: String,
    pub_key: String,
}

#[tokio::main]
async fn main() {
    let cli = cli::Cli::parse();

    match &cli.command {
        cli::Commands::Test { amount } => test_utxos(*amount).await,
        cli::Commands::FromIndexer {
            utxo_index_path,
            message,
            own_otxo_path,
        } => {
            from_indexer(
                utxo_index_path.as_str(),
                message.as_str(),
                own_otxo_path.as_str(),
            )
            .await
        }
    }
}

async fn from_indexer(utxo_index_path: &str, message: &str, own_otxo_path: &str) {
    let mut file = File::open(own_otxo_path).unwrap();
    let mut own_string: String = Default::default();
    file.read_to_string(&mut own_string).unwrap();
    let owned: Vec<OwnItem> = serde_json::from_str(&own_string).unwrap();
    let owned: HashMap<String, (String, String)> = owned
        .into_iter()
        .map(|e| (e.script_pub_key, (e.witness, e.pub_key)))
        .collect();

    let utxos_bytes = load_utxos(utxo_index_path).unwrap();
    let utxos = bytes_to_utxos(utxos_bytes, owned).unwrap();

    let message_hash = Sha256::digest(message);

    let rounded_leafs = (utxos.len() + MAX_COINS_DATABASE_AMOUNT - 1) / MAX_COINS_DATABASE_AMOUNT;

    write_consts().unwrap();

    //run first proof
    leafs_tomls(utxos.clone(), message_hash.as_ref()).unwrap();
    prove_leafs(rounded_leafs).await.unwrap();

    // run second proof
    let (mr, amount) = prove_nodes(rounded_leafs).await.unwrap();

    println!("Merkle root: {}, Amount: {}", mr, amount);
    get_merkle_root(utxos);
}

fn bytes_to_utxos(
    utxos_bytes: Vec<[u8; P2PKH_UTXO_SIZE]>,
    owned: HashMap<String, (String, String)>,
) -> Result<Vec<Utxo>> {
    let mut res = Vec::with_capacity(utxos_bytes.len());

    for i in 0..utxos_bytes.len() {
        let spk = hex::encode(&utxos_bytes[i][8..33]);

        let own = owned.get(&spk);
        let (witness, pub_key) = match own {
            Some(e) => (e.0.clone(), e.1.clone()),
            None => ("".to_string(), "".to_string()),
        };

        res.push(Utxo {
            amount: u64::from_le_bytes(utxos_bytes[i][0..8].try_into()?),
            script_pub_key: spk,
            witness,
            pub_key,
        });
    }

    Ok(res)
}

async fn test_utxos(amount: u32) {
    let message = "Test message";
    let priv_key = [1; 32];
    let utxos = generate_test_utxos(amount, message.as_ref(), &priv_key).unwrap();

    let message_hash = Sha256::digest(message);

    let rounded_leafs = (utxos.len() + MAX_COINS_DATABASE_AMOUNT - 1) / MAX_COINS_DATABASE_AMOUNT;

    write_consts().unwrap();

    //run first proof
    leafs_tomls(utxos.clone(), message_hash.as_ref()).unwrap();
    prove_leafs(rounded_leafs).await.unwrap();

    // run second proof
    let (mr, amount) = prove_nodes(rounded_leafs).await.unwrap();

    println!("Merkle root: {}, Amount: {}", mr, amount);
    get_merkle_root(utxos);
}

fn get_merkle_root(utxos: Vec<Utxo>) {
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

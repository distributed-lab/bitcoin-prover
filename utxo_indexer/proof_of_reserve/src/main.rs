use std::{
    collections::HashMap,
    fs::File,
    io::{Read, Write},
};

use anyhow::Result;
use bitcoin::hashes::{Hash, sha256};
use clap::Parser;
use indexer::load_utxos;
use k256::ecdsa::{Signature, SigningKey, signature::SignerMut};
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

const TEST_MESSAGE: &str = "Test message";

#[derive(Debug, Deserialize)]
struct OwnItem {
    script_pub_key: String,
    witness: String,
    pub_key: String,
}

#[tokio::main]
async fn main() {
    let cli = cli::Cli::parse();

    let (utxos, message) = match &cli.command {
        cli::Commands::Test { amount } => (test_utxos(*amount).unwrap(), TEST_MESSAGE),
        cli::Commands::FromIndexer {
            utxo_index_path,
            message,
            own_otxo_path,
        } => (
            from_indexer(utxo_index_path.as_str(), own_otxo_path.as_str()).unwrap(),
            message.as_str(),
        ),
        cli::Commands::Sign {
            private_key,
            message,
        } => {
            let sign = sign_message(
                hex::decode(private_key).unwrap().as_ref(),
                message.as_bytes(),
            )
            .unwrap();

            println!("Signature: {}", hex::encode(sign));
            return;
        }
    };

    let message_hash = Sha256::digest(message);

    let rounded_leafs = (utxos.len() + MAX_COINS_DATABASE_AMOUNT - 1) / MAX_COINS_DATABASE_AMOUNT;

    write_consts().unwrap();

    //run first proof
    leafs_tomls(utxos.as_ref(), message_hash.as_ref()).unwrap();
    prove_leafs(rounded_leafs).await.unwrap();

    // run second proof
    let (mr, amount) = prove_nodes(rounded_leafs).await.unwrap();

    println!("Merkle root: {}, Amount: {}", mr, amount);
    get_merkle_root(utxos.as_ref());
}

fn sign_message(priv_key: &[u8], message: &[u8]) -> Result<Vec<u8>> {
    let mut sign_key = SigningKey::from_bytes(priv_key)?;
    let signature: Signature = sign_key.sign(message);
    let normalized = signature.normalize_s().unwrap_or(signature).to_der();
    Ok(Vec::from(normalized.as_bytes()))
}

fn from_indexer(utxo_index_path: &str, own_otxo_path: &str) -> Result<Vec<Utxo>> {
    let mut file = File::open(own_otxo_path).unwrap();
    let mut own_string: String = Default::default();
    file.read_to_string(&mut own_string).unwrap();
    let owned: Vec<OwnItem> = serde_json::from_str(&own_string).unwrap();
    let owned: HashMap<String, (String, String)> = owned
        .into_iter()
        .map(|e| (e.script_pub_key, (e.witness, e.pub_key)))
        .collect();

    let utxos_bytes = load_utxos(utxo_index_path).unwrap();
    Ok(bytes_to_utxos(utxos_bytes.as_ref(), owned)?)
}

fn bytes_to_utxos(
    utxos_bytes: &[[u8; P2PKH_UTXO_SIZE]],
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

fn test_utxos(amount: u32) -> Result<Vec<Utxo>> {
    let priv_key = [1; 32];
    Ok(generate_test_utxos(
        amount,
        TEST_MESSAGE.as_bytes(),
        &priv_key,
    )?)
}

fn get_merkle_root(utxos: &[Utxo]) {
    let mut hashes = Vec::new();

    for i in utxos {
        let mut data = i.amount.to_le_bytes().to_vec();
        data.append(&mut hex::decode(i.script_pub_key.clone()).unwrap());

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

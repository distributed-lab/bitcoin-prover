mod bitcoin_primitives;
mod bitcoin_serialization;

mod cli;

use anyhow::{Context, Result};
use bitcoin::hashes::Hash;
use clap::Parser;
use rocksdb::{DB, IteratorMode, Options};
use std::{
    fs::File,
    io::{BufReader, BufWriter},
    path::Path,
};

use bitcoin::hashes::sha256;

use crate::{
    bitcoin_primitives::{CoinKey, CoinValue},
    bitcoin_serialization::deobfuscate,
};

const OBFUSCATION_KEY_DB_KEY: &[u8] = b"\x0e\x00obfuscate_key";
const P2PKH_UTXO_SIZE: usize = 8 + 25; // 8 bytes for amount, 25 bytes for P2PKH scriptPubKey

fn main() -> Result<()> {
    let cli = cli::Cli::parse();

    match &cli.command {
        cli::Commands::IndexChainstate {
            chainstate_path,
            output_path,
        } => run_index_chainstate(chainstate_path.as_str(), output_path.as_str()),
        cli::Commands::BuildMerkleRoot { utxo_index_path } => {
            run_build_merkle_root(utxo_index_path.as_str())
        }
    }
}

fn run_index_chainstate(chainstate_path: &str, output_path: &str) -> Result<()> {
    let mut opts = Options::default();
    opts.set_compression_type(rocksdb::DBCompressionType::Snappy);
    opts.create_if_missing(false);

    let db = DB::open_for_read_only(&opts, chainstate_path, false)?;
    let obfuscation_key_entry = db
        .get(OBFUSCATION_KEY_DB_KEY)
        .context("DB is not reachable")?
        .context("obfuscation key is not present in DB")?;

    println!(
        "Opened chainstate at {:?}. Using obfuscation key: {}",
        chainstate_path,
        hex::encode(&obfuscation_key_entry[1..])
    );
    println!("Parsing UTXO entries...");

    let iter = db.iterator(IteratorMode::Start);

    let mut p2pkh_count = 0;

    let mut utxos: Vec<[u8; P2PKH_UTXO_SIZE]> = Vec::with_capacity(100_000_000); // theoretical max amount of P2PKH UTXO in near future

    for (i, item) in iter.enumerate() {
        if i % 500_000 == 0 {
            println!(
                "Processed {} entries. Current P2PKH count: {}",
                i, p2pkh_count
            );
        }

        let (key, value) = item.context("DB is not reachable and iterable")?;

        let _coin_key = match CoinKey::deserialize(&key) {
            Some(ck) => ck,
            None => continue,
        };

        let deobfuscated_value = deobfuscate(&value, &obfuscation_key_entry[1..]);

        let coin_value = match CoinValue::deserialize(&deobfuscated_value) {
            Some(cv) => cv,
            None => continue,
        };

        p2pkh_count += 1;

        let mut utxo = Vec::with_capacity(P2PKH_UTXO_SIZE);
        utxo.extend_from_slice(&coin_value.amount.to_le_bytes());
        utxo.extend_from_slice(&coin_value.script_pubkey);

        utxos.push(utxo.try_into().expect("UTXO size should match"));
    }

    println!("Total P2PKH UTXO entries: {}", p2pkh_count);

    save_utxos(&utxos, output_path)?;

    println!("UTXO index saved to {}", output_path);

    Ok(())
}

fn run_build_merkle_root(utxo_index_path: &str) -> Result<()> {
    println!("Loading UTXO index from {}", utxo_index_path);

    let utxos = load_utxos(utxo_index_path)?;

    let mut merkle_tree_leaf_hashes: Vec<sha256::Hash> = Vec::with_capacity(utxos.len());
    for utxo in utxos {
        let leaf_hash = sha256::Hash::hash(&utxo);
        merkle_tree_leaf_hashes.push(leaf_hash);
    }

    let root = bitcoin::merkle_tree::calculate_root(merkle_tree_leaf_hashes.into_iter())
        .expect("UTXO set should not be empty");

    println!("Merkle root: {}", hex::encode(root.as_byte_array()));

    Ok(())
}

fn save_utxos(utxos: &Vec<[u8; P2PKH_UTXO_SIZE]>, path: &str) -> Result<()> {
    let file = File::create(path)?;
    let mut writer = BufWriter::new(file);
    bincode::encode_into_std_write(utxos, &mut writer, bincode::config::standard())?;
    Ok(())
}

fn load_utxos(path: &str) -> Result<Vec<[u8; P2PKH_UTXO_SIZE]>> {
    let file = File::open(path)?;
    let mut reader = BufReader::new(file);
    let utxos = bincode::decode_from_std_read(&mut reader, bincode::config::standard())?;
    Ok(utxos)
}

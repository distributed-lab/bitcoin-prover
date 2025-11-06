mod cli;
mod test_data_gen;

use clap::Parser;
use log::info;
use rand::Rng;
use std::fs::{self, File};
use std::io::Write;

use crate::test_data_gen::generate_test_utxos;

fn main() {
    env_logger::Builder::from_default_env()
        .filter_level(log::LevelFilter::Info)
        .init();

    let args = cli::Cli::parse();

    let message = args.const_message.as_bytes();

    let priv_key = match args.priv_key {
        Some(k) => hex::decode(k).unwrap(),
        None => Vec::new(),
    };

    let mut rng = rand::rng();

    let private_key: [u8; 32] = if priv_key.is_empty() {
        rng.random()
    } else {
        priv_key.as_slice().try_into().unwrap()
    };

    let test_utxos = generate_test_utxos(args.utxos_amount, &message, &private_key).unwrap();

    for elem in test_utxos.iter().clone() {
        println!(
            "SPK: {}\nAmount: {}\nWitness: {}\n",
            elem.script_pub_key, elem.amount, elem.witness,
        )
    }

    match args.output {
        Some(mut path) => {
            if path.extension().and_then(|s| s.to_str()) != Some("json") {
                path.set_extension("json");
            }

            if let Some(parent) = path.parent() {
                fs::create_dir_all(parent).unwrap();
            }

            let mut file = File::create(&path).unwrap();
            let as_json = serde_json::to_string_pretty(&test_utxos).unwrap();
            file.write_all(as_json.as_bytes()).unwrap();

            info!(
                "UTXOs were successfully saved to {}",
                path.to_str().unwrap()
            )
        }
        _ => (),
    }
}

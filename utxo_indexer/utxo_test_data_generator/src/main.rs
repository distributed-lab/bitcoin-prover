mod cli;
mod test_data_gen;

use clap::Parser;
use rand::Rng;

use crate::test_data_gen::generate_test_utxos;

fn main() {
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

    for elem in test_utxos {
        println!(
            "SPK: {}\nAmount: {}\nWitness: {}\n",
            hex::encode(&elem.script_pub_key),
            elem.amount,
            hex::encode(&elem.witness)
        )
    }
}

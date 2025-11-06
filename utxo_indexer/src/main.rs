mod cli;
mod test_data_gen;

use clap::Parser;
use sha2::{Digest, Sha256};

use crate::test_data_gen::generate_test_utxos;

fn main() {
    let args = cli::Cli::parse();

    let message = Sha256::digest(args.const_message).into();

    let test_utxos = generate_test_utxos(args.utxos_amount, message, args.priv_key).unwrap();

    for elem in test_utxos {
        println!(
            "SPK: {}\nAmount: {}\nWitness: {}\nPK: {}\n",
            hex::encode(&elem.script_pub_key),
            elem.amount,
            hex::encode(&elem.witness),
            hex::encode(&elem.private_key)
        )
    }
}

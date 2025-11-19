use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(version, about = "Builds UTXO index", long_about = None)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Use test UTXOs
    Test {
        /// Amount of test UTXOs
        #[arg(short, long)]
        amount: u32,
    },
    /// Use UTXOs from file
    FromIndexer {
        /// Path to the UTXO index file
        #[arg(short, long)]
        utxo_index_path: String,
        /// Message that was signed
        #[arg(short, long)]
        message: String,
        /// Path to json that contains owned utxos (see example in ./proof_of_reserve/own_example.json)
        #[arg(short, long)]
        own_otxo_path: String,
    },
    /// Create DER signature of message using private key
    Sign {
        /// Private key to sign the message (hex without "0x")
        #[arg(short, long)]
        private_key: String,
        /// Message that will be signed
        #[arg(short, long)]
        message: String,
    },
}

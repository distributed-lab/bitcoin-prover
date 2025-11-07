use clap::{Parser, Subcommand};

#[derive(Parser)]
#[command(version, about = "Builds UTXO index", long_about = None)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Commands,
}

#[derive(Subcommand)]
pub enum Commands {
    /// Index the chainstate and build the UTXO index
    IndexChainstate {
        /// Path to the chainstate LevelDB directory
        #[arg(short, long)]
        chainstate_path: String,
        /// Path to output the UTXO index file
        #[arg(short, long)]
        output_path: String,
    },
    BuildMerkleRoot {
        /// Path to the UTXO index file
        #[arg(short, long)]
        utxo_index_path: String,
    },
}

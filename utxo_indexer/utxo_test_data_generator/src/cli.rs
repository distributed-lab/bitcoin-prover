use std::path::PathBuf;

use clap::Parser;

#[derive(Parser)]
#[command(version, about = "Sync blockchain block headers", long_about = None)]
pub struct Cli {
    /// Amount of utxos that will be generated
    #[arg(long, default_value = "20")]
    pub utxos_amount: u32,

    /// Message that will be signed with private key
    #[arg(long, default_value = "const message")]
    pub const_message: String,

    /// Private key in hex (will be generated if it doesn't set)
    #[arg(long)]
    pub priv_key: Option<String>,

    /// Path to file where generated utxos will be saved
    #[arg(long)]
    pub output: Option<PathBuf>,
}

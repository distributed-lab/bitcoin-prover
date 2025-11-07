use std::{
    fs::File,
    io::{BufReader, BufWriter},
};

use anyhow::Result;

pub const P2PKH_UTXO_SIZE: usize = 8 + 25; // 8 bytes for amount, 25 bytes for P2PKH scriptPubKey

pub fn save_utxos(utxos: &Vec<[u8; P2PKH_UTXO_SIZE]>, path: &str) -> Result<()> {
    let file = File::create(path)?;
    let mut writer = BufWriter::new(file);
    bincode::encode_into_std_write(utxos, &mut writer, bincode::config::standard())?;

    Ok(())
}

pub fn load_utxos(path: &str) -> Result<Vec<[u8; P2PKH_UTXO_SIZE]>> {
    let file = File::open(path)?;
    let mut reader = BufReader::new(file);
    let utxos = bincode::decode_from_std_read(&mut reader, bincode::config::standard())?;

    Ok(utxos)
}

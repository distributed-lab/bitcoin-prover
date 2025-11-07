use anyhow::{Context, Result};
use bitcoin::{
    Txid, VarInt, consensus,
    hashes::Hash,
    opcodes::all::{OP_CHECKSIG, OP_DUP, OP_EQUALVERIFY, OP_HASH160},
};
use rocksdb::{DB, IteratorMode, Options};
use std::path::Path;

const OBFUSCATION_KEY_DB_KEY: &[u8] = b"\x0e\x00obfuscate_key";

fn main() -> Result<()> {
    let path = Path::new(
        "/Users/user/Documents/Projects/cryptography/bitcoin-prover/utxo_indexer/chainstate.dev.db",
    );
    let mut opts = Options::default();

    opts.set_compression_type(rocksdb::DBCompressionType::Snappy);

    opts.create_if_missing(false);

    let db = DB::open_for_read_only(&opts, path, false)?;

    let obfuscation_key_entry = db
        .get(OBFUSCATION_KEY_DB_KEY)
        .context("DB is not reachable")?
        .context("obfuscation key is not present in DB")?;

    println!(
        "Opened chainstate at {:?}. Using obfuscation key: {}",
        path,
        hex::encode(&obfuscation_key_entry[1..])
    );
    println!("Parsing UTXO entries...");

    let iter = db.iterator(IteratorMode::Start);

    let mut p2pkh_count = 0;

    let mut merkle_tree_leaf_hashes: Vec<bitcoin::hashes::sha256::Hash> =
        Vec::with_capacity(40_000_000);

    for (i, item) in iter.enumerate() {
        if i % 100_000 == 0 {
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

        // println!(
        //     "ENTRY #{}, KEY: {}, DEOBFUSCATED VALUE RAW: {}",
        //     i,
        //     hex::encode(&key),
        //     hex::encode(&deobfuscated_value)
        // );

        // println!(
        //     "ENTRY #{}, TXID: {}, VOUT: {}; HEIGHT: {}, IS_COINBASE: {}, AMOUNT: {}, SCRIPT_PUBKEY: {}",
        //     i,
        //     coin_key.txid,
        //     coin_key.vout.0,
        //     coin_value.height,
        //     coin_value.is_coinbase,
        //     coin_value.amount,
        //     hex::encode(&coin_value.script_pubkey)
        // );

        p2pkh_count += 1;

        let mut leaf_data = Vec::with_capacity(8 + 25);
        leaf_data.extend_from_slice(&coin_value.amount.to_le_bytes());
        leaf_data.extend_from_slice(&coin_value.script_pubkey);

        let leaf_hash = bitcoin::hashes::sha256::Hash::hash(&leaf_data);
        merkle_tree_leaf_hashes.push(leaf_hash);
    }

    println!("Total P2PKH UTXO entries: {}", p2pkh_count);

    let root = bitcoin::merkle_tree::calculate_root(merkle_tree_leaf_hashes.into_iter()).unwrap();

    println!(
        "Merkle root of all P2PKH UTXO entries: {}",
        hex::encode(root.as_byte_array())
    );

    Ok(())
}

fn deobfuscate(data: &[u8], obfuscation_key: &[u8]) -> Vec<u8> {
    if obfuscation_key.is_empty() {
        return data.to_vec();
    }

    data.iter()
        .enumerate()
        .map(|(i, &byte)| byte ^ obfuscation_key[i % obfuscation_key.len()])
        .collect()
}

#[derive(Debug)]
struct CoinKey {
    pub txid: Txid,
    pub vout: VarInt,
}

impl CoinKey {
    const COIN_DELIMITER: u8 = 0x43; // 'C'

    const MINIMUM_KEY_SIZE: usize = 1 + 32 + 1; // 1 byte prefix + 32 bytes txid + at least 1 byte vout

    pub fn deserialize(data: &[u8]) -> Option<Self> {
        if data.len() < Self::MINIMUM_KEY_SIZE {
            return None;
        }

        let txid = Txid::from_slice(&data[1..33]).ok()?;
        let vout = consensus::deserialize(&data[33..]).ok()?;

        Some(Self { txid, vout })
    }

    #[allow(unused)]
    pub fn serialize(&self) -> Vec<u8> {
        let mut result = Vec::with_capacity(1 + 32 + self.vout.size());
        result.push(Self::COIN_DELIMITER);
        result.extend_from_slice(self.txid.as_raw_hash().as_byte_array());
        result.extend_from_slice(&consensus::serialize(&self.vout));
        result
    }
}

#[derive(Debug)]
struct CoinValue {
    pub height: u64,
    #[allow(unused)]
    pub is_coinbase: bool,
    pub amount: u64,
    pub script_pubkey: Vec<u8>,
}

impl CoinValue {
    const P2PKH_COAT_OF_ARMS: u64 = 0x00;
    const P2PKH_SCRIPT_LEN: usize = 25;
    const PKH_SIZE: usize = 20;

    pub fn deserialize(data: &[u8]) -> Option<Self> {
        let mut cursor = 0;

        let (code, consumed) = Self::read_var_int_u32(data)?;

        cursor += consumed;

        let height = code >> 1;

        let is_coinbase = (code & 1) == 1;

        let (compressed_amount, consumed) = Self::read_var_int_u32(&data[cursor..])?;
        cursor += consumed;

        let amount = Self::decompress_amount(compressed_amount as u64);

        let (script_len, consumed) = Self::read_var_int_u64(&data[cursor..])?;

        // TODO: implement the other script types
        if Self::P2PKH_COAT_OF_ARMS != script_len {
            return None;
        }

        cursor += consumed;

        if data.len() < cursor + Self::PKH_SIZE {
            return None;
        }

        let mut pkh = data[cursor..cursor + Self::PKH_SIZE].to_vec();

        let mut script_pubkey = Vec::with_capacity(Self::P2PKH_SCRIPT_LEN);
        script_pubkey.push(OP_DUP.to_u8());
        script_pubkey.push(OP_HASH160.to_u8());
        script_pubkey.push(20);
        script_pubkey.append(&mut pkh);
        script_pubkey.push(OP_EQUALVERIFY.to_u8());
        script_pubkey.push(OP_CHECKSIG.to_u8());

        Some(Self {
            height: height as u64,
            is_coinbase,
            amount,
            script_pubkey,
        })
    }

    fn read_var_int_u64(data: &[u8]) -> Option<(u64, usize)> {
        let mut result: u64 = 0;
        let mut consumed = 0;

        for byte in data {
            consumed += 1;

            if result > (u64::MAX >> 7) {
                return None;
            }

            result = (result << 7) | u64::from(byte & 0x7F);
            if byte & 0x80 != 0x00 {
                if result == u64::MAX {
                    return None;
                }

                result += 1;
            } else {
                return Some((result, consumed));
            }
        }

        None
    }

    fn read_var_int_u32(data: &[u8]) -> Option<(u32, usize)> {
        let mut result: u32 = 0;
        let mut consumed = 0;

        for byte in data {
            consumed += 1;

            if result > (u32::MAX >> 7) {
                return None;
            }

            result = (result << 7) | u32::from(byte & 0x7F);
            if byte & 0x80 != 0x00 {
                if result == u32::MAX {
                    return None;
                }

                result += 1;
            } else {
                return Some((result, consumed));
            }
        }

        None
    }

    fn decompress_amount(x: u64) -> u64 {
        if x == 0 {
            return 0;
        }

        let mut x = x - 1;
        let e = (x % 10) as u32;
        x /= 10;

        if e < 9 {
            let d = (x % 9) + 1;
            let n = x / 9;
            let n_full = n * 10 + d;

            n_full * 10u64.pow(e)
        } else {
            (x + 1) * 10u64.pow(9)
        }
    }
}

#[cfg(test)]
mod tests {
    use std::str::FromStr;

    use bitcoin::Txid;

    #[test]
    fn test_coin_key_deserialize() {
        let key =
            hex::decode("435a7b146bcde2a1f879c367fbbbac97a401aef899430182effb998d4ff1452a6d06")
                .unwrap();

        let tx_id =
            Txid::from_str("6d2a45f14f8d99fbef82014399f8ae01a497acbbfb67c379f8a1e2cd6b147b5a")
                .unwrap();

        let deserialized = super::CoinKey::deserialize(&key).unwrap();

        assert_eq!(deserialized.txid, tx_id);
        assert_eq!(deserialized.vout, 6u32.into());
    }
}

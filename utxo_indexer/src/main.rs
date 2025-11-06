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
    opts.create_if_missing(false);

    let db = DB::open_for_read_only(&opts, path, false)?;

    let obfuscation_key = db
        .get(OBFUSCATION_KEY_DB_KEY)
        .context("DB is not reachable")?
        .context("obfuscation key is not present in DB")?;

    // let obfuscation_key = hex::decode("3c1be7ab41a2f690").unwrap();

    // let key = hex::decode("435a7b146bcde2a1f879c367fbbbac97a401aef899430182effb998d4ff1452a6d06")?;

    // let value = db.get(&key)?.unwrap();

    // let deobfuscated_value = deobfuscate(&value, &obfuscation_key);

    // if let Some(coin_value) = CoinValue::deserialize(&deobfuscated_value) {
    //     println!(
    //         "  height: {}, is_coinbase: {}, amount: {}, script_pubkey: {}",
    //         coin_value.height,
    //         coin_value.is_coinbase,
    //         coin_value.amount,
    //         hex::encode(&coin_value.script_pubkey)
    //     );
    // }

    println!("Opened chainstate at {:?}", path);
    println!("Parsing UTXO entries...");

    let iter = db.iterator(IteratorMode::Start);

    for (i, item) in iter.enumerate() {
        if i < 408 {
            continue;
        }

        if i > 408 {
            break;
        }

        let (key, value) = item.context("DB is not reachable and iterable")?;

        let coin_key = match CoinKey::deserialize(&key) {
            Some(ck) => ck,
            None => continue,
        };

        let deobfuscated_value = deobfuscate(&value, &obfuscation_key);

        let coin_value = match CoinValue::deserialize(&deobfuscated_value) {
            Some(cv) => cv,
            None => continue,
        };

        println!("raw value: {}", hex::encode(&value));

        println!(
            "ENTRY #{}, KEY: {}, DEOBFUSCATED VALUE RAW: {}",
            i,
            hex::encode(&key),
            hex::encode(&deobfuscated_value)
        );

        println!(
            "ENTRY #{}, TXID: {}, VOUT: {}; HEIGHT: {}, AMOUNT: {}, SCRIPT_PUBKEY: {}",
            i,
            coin_key.txid,
            coin_key.vout.0,
            coin_value.height,
            coin_value.amount,
            hex::encode(&coin_value.script_pubkey)
        )
    }

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

        let (code, consumed) = Self::read_var_int_u64(data).ok()?;

        println!("code: {}, consumed: {}", code, consumed);

        cursor += consumed;

        let height = code >> 1;

        let is_coinbase = (code & 1) == 1;

        let (compressed_amount, consumed) = Self::read_var_int_u64(&data[cursor..]).ok()?;
        cursor += consumed;

        let amount = Self::decompress_amount(compressed_amount);

        let (script_len, consumed) = Self::read_var_int_u64(&data[cursor..]).ok()?;

        // TODO: implement the other script types
        if Self::P2PKH_COAT_OF_ARMS != script_len {
            return None;
        }

        cursor += consumed;

        let mut pkh = data[cursor..cursor + Self::PKH_SIZE].to_vec();

        let mut script_pubkey = Vec::with_capacity(Self::P2PKH_SCRIPT_LEN);
        script_pubkey.push(OP_DUP.to_u8());
        script_pubkey.push(OP_HASH160.to_u8());
        script_pubkey.push(20);
        script_pubkey.append(&mut pkh);
        script_pubkey.push(OP_EQUALVERIFY.to_u8());
        script_pubkey.push(OP_CHECKSIG.to_u8());

        Some(Self {
            height,
            is_coinbase,
            amount,
            script_pubkey,
        })
    }

    // while(true) {
    //     unsigned char chData = ser_readdata8(is);
    //     if (n > (std::numeric_limits<I>::max() >> 7)) {
    //        throw std::ios_base::failure("ReadVarInt(): size too large");
    //     }
    //     n = (n << 7) | (chData & 0x7F);
    //     if (chData & 0x80) {
    //         if (n == std::numeric_limits<I>::max()) {
    //             throw std::ios_base::failure("ReadVarInt(): size too large");
    //         }
    //         n++;
    //     } else {
    //         return n;
    //     }
    // }

    fn read_var_int_u64(data: &[u8]) -> Result<(u64, usize)> {
        let mut n: u64 = 0;
        let mut size: usize = 0;

        for byte in data {
            size += 1;

            if n > (u64::MAX >> 7) {
                anyhow::bail!("ReadVarInt(): size too large");
            }

            n = (n << 7) | u64::from(byte & 0x7f);
            if byte & 0x80 != 0x80 {
                break;
            }

            n += 1;
        }

        Ok((n, size))
    }

    //     uint64_t DecompressAmount(uint64_t x)
    // {
    //     // x = 0  OR  x = 1+10*(9*n + d - 1) + e  OR  x = 1+10*(n - 1) + 9
    //     if (x == 0)
    //         return 0;
    //     x--;
    //     // x = 10*(9*n + d - 1) + e
    //     int e = x % 10;
    //     x /= 10;
    //     uint64_t n = 0;
    //     if (e < 9) {
    //         // x = 9*n + d - 1
    //         int d = (x % 9) + 1;
    //         x /= 9;
    //         // x = n
    //         n = x*10 + d;
    //     } else {
    //         n = x+1;
    //     }
    //     while (e) {
    //         n *= 10;
    //         e--;
    //     }
    //     return n;
    // }

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

    #[test]
    fn code_encoding() {
        //         void WriteVarInt(Stream& os, I n)
        // {
        //     CheckVarIntMode<Mode, I>();
        //     unsigned char tmp[(sizeof(n)*8+6)/7];
        //     int len=0;
        //     while(true) {
        //         tmp[len] = (n & 0x7F) | (len ? 0x80 : 0x00);
        //         if (n <= 0x7F)
        //             break;
        //         n = (n >> 7) - 1;
        //         len++;
        //     }
        //     do {
        //         ser_writedata8(os, tmp[len]);
        //     } while(len--);
        // }

        let height: u64 = 686482;
        let is_coinbase: u64 = 0;

        let code = height * 2 + is_coinbase;

        let encoded = {
            let mut n = code;
            let mut tmp = Vec::new();

            loop {
                let byte = (n & 0x7F) as u8 | if tmp.is_empty() { 0x00 } else { 0x80 };
                tmp.push(byte);
                if n <= 0x7F {
                    break;
                }
                n = (n >> 7) - 1;
            }

            tmp.reverse();
            tmp
        };

        println!("Encoded code bytes: {}", hex::encode(&encoded));

        let (result, _) = read_var_int_u64(&encoded).unwrap();

        println!("Decoded code: {}", result);

        let decoded_height = result >> 1;
        let decoded_is_coinbase = result & 1;

        println!("Decoded height: {}", decoded_height);
        println!("Decoded is_coinbase: {}", decoded_is_coinbase);
    }

    fn read_var_int_u64(data: &[u8]) -> anyhow::Result<(u64, usize)> {
        let mut n: u64 = 0;
        let mut size: usize = 0;

        for byte in data {
            size += 1;
            n = (n << 7) | u64::from(byte & 0x7f);
            if byte & 0x80 != 0x80 {
                break;
            }

            n += 1;
        }

        Ok((n, size))
    }
}

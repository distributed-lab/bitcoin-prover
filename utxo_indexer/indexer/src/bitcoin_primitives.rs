use crate::bitcoin_serialization::{decompress_amount, read_var_int_u32, read_var_int_u64};

use bitcoin::{
    Txid, VarInt, consensus,
    hashes::Hash,
    opcodes::all::{OP_CHECKSIG, OP_DUP, OP_EQUALVERIFY, OP_HASH160},
};

#[allow(unused)]
#[derive(Debug)]
pub struct CoinKey {
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

#[allow(unused)]
#[derive(Debug)]
pub struct CoinValue {
    pub height: u64,
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

        let (code, consumed) = read_var_int_u32(data)?;

        cursor += consumed;

        let height = code >> 1;

        let is_coinbase = (code & 1) == 1;

        let (compressed_amount, consumed) = read_var_int_u32(&data[cursor..])?;
        cursor += consumed;

        let amount = decompress_amount(compressed_amount as u64);

        let (script_len, consumed) = read_var_int_u64(&data[cursor..])?;

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

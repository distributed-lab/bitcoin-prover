use anyhow::{Ok, Result};
use bitcoin::{
    opcodes::all::{OP_CHECKSIG, OP_DUP, OP_EQUALVERIFY, OP_HASH160},
    script::Builder,
};
use k256::{
    ecdsa::{Signature, SigningKey, signature::Signer},
    elliptic_curve::sec1::ToEncodedPoint,
};
use rand::Rng;
use ripemd::Ripemd160;
use sha2::{Digest, Sha256};

#[allow(dead_code)]
pub struct TestUtxo {
    pub amount: u64,
    pub script_pub_key: Vec<u8>,
    pub witness: Vec<u8>,
}

#[allow(dead_code)]
pub fn generate_test_utxos(
    utxos_amount: u32,
    message: &[u8],
    priv_key: &[u8; 32],
) -> Result<Vec<TestUtxo>> {
    let mut rng = rand::rng();
    let mut res: Vec<TestUtxo> = Vec::with_capacity(utxos_amount as usize);

    for _ in 0..utxos_amount {
        let amount: u64 = rng.random_range(1000..=10000000);

        let sign_key = SigningKey::from_bytes(priv_key)?;
        let pub_key = sign_key.verifying_key().to_encoded_point(true);
        let pub_key_bytes = pub_key.as_bytes();

        let signature: Signature = sign_key.sign(message);
        let normalized = signature.normalize_s().unwrap_or(signature).to_der();
        let der_bytes = normalized.as_bytes();

        let script_pub_key = Builder::new()
            .push_opcode(OP_DUP)
            .push_opcode(OP_HASH160)
            .push_slice(hash160(pub_key_bytes))
            .push_opcode(OP_EQUALVERIFY)
            .push_opcode(OP_CHECKSIG);

        res.push(TestUtxo {
            amount,
            script_pub_key: script_pub_key.into_bytes(),
            witness: Vec::from(der_bytes),
        });
    }

    Ok(res)
}

pub fn hash160(data: &[u8]) -> [u8; 20] {
    let sha256_hash = Sha256::digest(data);
    let ripemd_hash = Ripemd160::digest(sha256_hash);

    let mut result = [0; 20];
    result.copy_from_slice(&ripemd_hash);
    result
}

#[cfg(test)]
mod tests {
    use crate::test_data_gen::{generate_test_utxos, hash160};
    use k256::{
        ecdsa::{Signature, SigningKey, signature::Verifier},
        elliptic_curve::sec1::ToEncodedPoint,
    };

    #[test]
    fn text_gen() {
        let priv_key = [1; 32];
        let utxos = generate_test_utxos(10, &[0; 32], &priv_key).unwrap();

        for i in 0..10 {
            let sign_key = SigningKey::from_bytes(&priv_key).unwrap();
            let ver_key = sign_key.verifying_key();

            assert!(
                hash160(ver_key.to_encoded_point(true).to_bytes().as_ref())
                    == utxos[i].script_pub_key[3..23]
            );

            let sign = Signature::from_der(&utxos[i].witness).unwrap();
            ver_key.verify(&[0; 32], &sign).unwrap();
        }
    }
}

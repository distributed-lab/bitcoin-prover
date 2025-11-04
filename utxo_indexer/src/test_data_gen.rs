use anyhow::{Ok, Result};
use k256::{
    ecdsa::{Signature, SigningKey, signature::Signer},
    elliptic_curve::sec1::ToEncodedPoint,
};
use rand::Rng;
use ripemd::Ripemd160;
use sha2::{Digest, Sha256};

pub struct TestUtxo {
    pub amount: u64,
    pub script_pub_key: Vec<u8>,
    pub witness: Vec<u8>,
    pub private_key: [u8; 32],
}

pub fn generate_test_utxos(utxos_amount: u32, message: [u8; 32]) -> Result<Vec<TestUtxo>> {
    let mut rng = rand::rng();
    let mut res: Vec<TestUtxo> = Vec::new();

    for _ in 0..utxos_amount {
        let amount: u64 = rng.random_range(1000..=100000000);
        let private_key: [u8; 32] = rng.random();

        let sign_key = SigningKey::from_bytes(&private_key)?;
        let pub_key = sign_key.verifying_key().to_encoded_point(true);
        let pub_key_bytes = pub_key.as_bytes();

        let signature: Signature = sign_key.sign(&message);
        let normalized = signature.normalize_s().unwrap_or(signature).to_der();
        let der_bytes = normalized.as_bytes();

        let mut script_pub_key = vec![118, 169, 20];
        script_pub_key.append(&mut Vec::from(hash160(pub_key_bytes)));
        script_pub_key.append(&mut vec![136, 172]);

        res.push(TestUtxo {
            amount,
            script_pub_key,
            witness: Vec::from(der_bytes),
            private_key,
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
        let utxos = generate_test_utxos(10, [0; 32]).unwrap();

        for i in 0..10 {
            let sign_key = SigningKey::from_bytes(&utxos[i].private_key).unwrap();
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

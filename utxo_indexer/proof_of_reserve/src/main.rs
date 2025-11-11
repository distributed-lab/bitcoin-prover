use anyhow::{Ok, Result};
use k256::{ecdsa::SigningKey, elliptic_curve::sec1::ToEncodedPoint};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::fs::{self, File};
use std::io::Write;
use std::process::Command;
use utxo_test_data_generator::test_data_gen::{TestUtxo, generate_test_utxos};

const MAX_COINS_DATABASE_AMOUNT: usize = 5;
const MAX_NODES_AMOUNT: usize = 8;

#[derive(Serialize, Deserialize)]
struct CoinsDatabaseElement {
    script_pub_key: Vec<u8>,
    amount: u64,
}

#[derive(Serialize, Deserialize)]
struct Spending {
    witness: Vec<u8>, // 72 bytes
    pub_key: Vec<u8>, // 65 bytes
}

#[derive(Serialize, Deserialize)]
struct LeafsToml {
    const_message_hash: Vec<u8>,
    coins_database: Vec<CoinsDatabaseElement>,
    own_utxos: Vec<Spending>,
}

#[derive(Serialize, Deserialize)]
struct NodeProof {
    proof: Vec<String>,
    public_inputs: Vec<String>,
}

#[derive(Serialize, Deserialize)]
struct NodeToml {
    verification_key: Vec<String>,
    key_hash: String,
    node_proofs: Vec<NodeProof>,
}

fn main() {
    let message = "Hello, world!";
    let priv_key = [1; 32];
    let utxos = generate_test_utxos(4, message.as_ref(), &priv_key).unwrap();

    let sk = SigningKey::from_bytes(&priv_key).unwrap();
    let pk = sk.verifying_key();

    let message_hash = Sha256::digest(message);
    let pub_key = pk.to_encoded_point(true);

    // run first proof

    leafs_toml(utxos, message_hash.as_ref(), pub_key.as_bytes()).unwrap();

    let status = Command::new("bash")
        .arg("-c")
        .arg("nargo execute")
        .current_dir("../circuits/app/proof_of_reserve/coins")
        .status()
        .expect("failed to execute command");

    assert!(status.success(), "Command return non-zero status");

    fs::create_dir_all("../circuits/target/vk/leafs").unwrap();
    fs::create_dir_all("../circuits/target/vk/tree").unwrap();

    let status = Command::new("bash")
        .arg("-c")
        .arg("bb write_vk -b ../../../target/coins.json -o ../../../target/vk/leafs")
        .current_dir("../circuits/app/proof_of_reserve/coins")
        .status()
        .expect("failed to execute command");

    assert!(status.success(), "Command return non-zero status");

    fs::create_dir_all("../circuits/target/proof/leafs").unwrap();

    let status = Command::new("bash")
        .arg("-c")
        .arg("bb prove -b ../../../target/coins.json -w ../../../target/coins.gz -o ../../../target/proof/leafs -k ../../../target/vk/leafs/vk")
        .current_dir("../circuits/app/proof_of_reserve/coins")
        .status()
        .expect("failed to execute command");

    assert!(status.success(), "Command return non-zero status");

    // run second proof

    tree_toml().unwrap();

    let status = Command::new("bash")
        .arg("-c")
        .arg("nargo execute")
        .current_dir("../circuits/app/proof_of_reserve/utxos_tree")
        .status()
        .expect("failed to execute command");

    assert!(status.success(), "Command return non-zero status");

    let status = Command::new("bash")
        .arg("-c")
        .arg("bb write_vk -b ../../../target/utxos_tree.json -o ../../../target/vk/tree")
        .current_dir("../circuits/app/proof_of_reserve/utxos_tree")
        .status()
        .expect("failed to execute command");

    assert!(status.success(), "Command return non-zero status");

    let status = Command::new("bash")
        .arg("-c")
        .arg("bb prove -b ../../../target/utxos_tree.json -w ../../../target/utxos_tree.gz -o ../../../target/proof/leafs -k ../../../target/vk/tree/vk")
        .current_dir("../circuits/app/proof_of_reserve/utxos_tree")
        .status()
        .expect("failed to execute command");

    assert!(status.success(), "Command return non-zero status");
}

fn leafs_toml(utxos: Vec<TestUtxo>, message_hash: &[u8; 32], public_key: &[u8]) -> Result<()> {
    let mut coins_database: Vec<CoinsDatabaseElement> = utxos
        .iter()
        .map(|e| CoinsDatabaseElement {
            script_pub_key: hex::decode(&e.script_pub_key).unwrap(),
            amount: e.amount,
        })
        .collect();

    let append_from = coins_database.len();
    let append_to = ((coins_database.len() + MAX_COINS_DATABASE_AMOUNT - 1)
        / MAX_COINS_DATABASE_AMOUNT)
        * MAX_COINS_DATABASE_AMOUNT;

    for _ in append_from..append_to {
        coins_database.push(CoinsDatabaseElement {
            script_pub_key: Vec::from([0; 25]),
            amount: 0,
        });
    }

    let mut pub_key = Vec::from(public_key);
    if pub_key.len() < 65 {
        pub_key.resize(65, 0);
    }

    let mut own_utxos: Vec<Spending> = utxos
        .iter()
        .map(|e| {
            let mut witness = hex::decode(&e.witness).unwrap();
            if witness.len() < 72 {
                witness.resize(72, 0);
            }

            Spending { witness, pub_key: pub_key.clone() }
        })
        .collect();

    let append_from = own_utxos.len();
    let append_to = ((own_utxos.len() + MAX_COINS_DATABASE_AMOUNT - 1) / MAX_COINS_DATABASE_AMOUNT)
        * MAX_COINS_DATABASE_AMOUNT;

    for _ in append_from..append_to {
        own_utxos.push(Spending {
            witness: Vec::from([0; 72]),
            pub_key: Vec::from([0; 65]),
        });
    }

    let toml_struct = LeafsToml {
        const_message_hash: Vec::from(message_hash),
        coins_database,
        own_utxos,
    };

    let mut file = File::create("../circuits/app/proof_of_reserve/coins/Prover.toml")?;
    file.write(toml::to_string(&toml_struct)?.as_bytes())?;

    Ok(())
}

fn tree_toml() -> Result<()> {
    let proof = fs::read("../circuits/target/proof/leafs/proof")?;
    let pi = fs::read("../circuits/target/proof/leafs/public_inputs")?;
    let vk = fs::read("../circuits/target/vk/leafs/vk")?;
    let vk_hash = fs::read("../circuits/target/vk/leafs/vk_hash")?;

    let mut proof_strings: Vec<String> = Vec::new();
    let mut pi_strings: Vec<String> = Vec::new();
    let mut vk_strings: Vec<String> = Vec::new();

    for byte in proof.chunks(32) {
        proof_strings.push("0x".to_owned() + &hex::encode(byte));
    }

    for byte in pi.chunks(32) {
        pi_strings.push("0x".to_owned() + &hex::encode(byte));
    }

    for byte in vk.chunks(32) {
        vk_strings.push("0x".to_owned() + &hex::encode(byte));
    }

    let node_toml = NodeToml {
        verification_key: vk_strings,
        key_hash: "0x".to_owned() + &hex::encode(vk_hash),
        node_proofs: vec![NodeProof {
            proof: proof_strings,
            public_inputs: pi_strings,
        }],
    };

    let mut file = File::create("../circuits/app/proof_of_reserve/utxos_tree/Prover.toml")?;
    file.write(toml::to_string(&node_toml)?.as_bytes())?;

    Ok(())
}

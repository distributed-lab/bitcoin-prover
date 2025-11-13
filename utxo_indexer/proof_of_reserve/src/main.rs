use anyhow::{Ok, Result};
use bitcoin::hashes::{Hash, sha256};
use futures::future::join_all;
use k256::{ecdsa::SigningKey, elliptic_curve::sec1::ToEncodedPoint};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::fs::{self, File};
use std::io::Write;
use std::process::Command;
use std::sync::Arc;
use tokio::sync::Semaphore;
use utxo_test_data_generator::test_data_gen::{TestUtxo, generate_test_utxos};

const MAX_COINS_DATABASE_AMOUNT: usize = 8;
const MAX_NODES_AMOUNT: usize = 8;
const MAX_ASYNC_TASKS: usize = 2;

#[derive(Serialize, Deserialize, Clone)]
struct CoinsDatabaseElement {
    script_pub_key: Vec<u8>,
    amount: u64,
}

#[derive(Serialize, Deserialize, Clone)]
struct Spending {
    witness: Vec<u8>, // 72 bytes
    pub_key: Vec<u8>, // 65 bytes
}

#[derive(Serialize, Deserialize)]
struct LeafsToml {
    const_message_hash: Vec<u8>,
    coins_database: Vec<CoinsDatabaseElement>,
    own_utxos: Vec<Spending>,
    finalize_mr: bool,
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
    finalize_mr: bool,
}

#[tokio::main]
async fn main() {
    let message = "Hello, world!";
    let priv_key = [1; 32];
    let utxos = generate_test_utxos(9, message.as_ref(), &priv_key).unwrap();

    let total_amount: u64 = utxos.iter().map(|u| u.amount).sum();

    let sk = SigningKey::from_bytes(&priv_key).unwrap();
    let pk = sk.verifying_key();

    let message_hash = Sha256::digest(message);
    let pub_key = pk.to_encoded_point(true);

    let rounded_leafs = (utxos.len() + MAX_COINS_DATABASE_AMOUNT - 1) / MAX_COINS_DATABASE_AMOUNT;

    //run first proof
    leafs_tomls(utxos.clone(), message_hash.as_ref(), pub_key.as_bytes()).unwrap();
    prove_leafs(rounded_leafs).await;

    // run second proof
    let (mr, amount) = prove_nodes(rounded_leafs).await;

    println!("Merkle root: {}, Amount: {}", mr, amount);
    get_merkle_root(utxos);
    println!("Expected amount: {}", total_amount)
}

fn get_merkle_root(utxos: Vec<TestUtxo>) {
    let mut hashes = Vec::new();

    for i in utxos {
        let mut data = i.amount.to_le_bytes().to_vec();
        data.append(&mut hex::decode(i.script_pub_key).unwrap());

        let hash = Sha256::digest(data);
        hashes.push(hash.to_vec());
    }

    let hashes: Vec<sha256::Hash> = hashes
        .into_iter()
        .map(|h| sha256::Hash::from_slice(&h).unwrap())
        .collect();

    let merkle_root = bitcoin::merkle_tree::calculate_root(hashes.iter().cloned()).unwrap();
    println!("Expected merkle root: {merkle_root}");
}

fn leafs_tomls(utxos: Vec<TestUtxo>, message_hash: &[u8; 32], public_key: &[u8]) -> Result<()> {
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

            Spending {
                witness,
                pub_key: pub_key.clone(),
            }
        })
        .collect();

    let append_from = own_utxos.len();

    for _ in append_from..append_to {
        own_utxos.push(Spending {
            witness: Vec::from([0; 72]),
            pub_key: Vec::from([0; 65]),
        });
    }

    let chunks = append_to / MAX_COINS_DATABASE_AMOUNT;

    for i in 0..chunks {
        let toml_struct = LeafsToml {
            const_message_hash: Vec::from(message_hash),
            coins_database: coins_database
                [(i * MAX_COINS_DATABASE_AMOUNT)..((i + 1) * MAX_COINS_DATABASE_AMOUNT)]
                .to_vec(),
            own_utxos: own_utxos
                [(i * MAX_COINS_DATABASE_AMOUNT)..((i + 1) * MAX_COINS_DATABASE_AMOUNT)]
                .to_vec(),
            finalize_mr: i != 0,
        };

        let mut file = File::create(format!(
            "../circuits/app/proof_of_reserve/coins/provers/Prover{}.toml",
            i + 1
        ))?;
        file.write(toml::to_string(&toml_struct)?.as_bytes())?;
    }

    Ok(())
}

async fn prove_leafs(chunks: usize) {
    let status = Command::new("bash")
        .arg("-c")
        .arg("nargo compile")
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

    fs::create_dir_all("../circuits/target/coins").unwrap();

    // Async
    let semaphore = Arc::new(Semaphore::new(MAX_ASYNC_TASKS));
    let mut tasks = Vec::new();

    for i in 0..chunks {
        let permit = semaphore.clone().acquire_owned().await.unwrap();

        let task = tokio::spawn(async move {
            let status = Command::new("bash")
                .arg("-c")
                .arg(format!(
                    "nargo execute -p ./provers/Prover{}.toml ./coins/witness/coins{}.gz",
                    i + 1,
                    i + 1,
                ))
                .current_dir("../circuits/app/proof_of_reserve/coins")
                .status()
                .expect("failed to execute command");

            assert!(status.success(), "Command return non-zero status");

            let status = Command::new("bash")
                .arg("-c")
                .arg(format!("bb prove -b ../../../target/coins.json -w ../../../target/coins/witness/coins{}.gz -o ../../../target/coins/proofs/proof_0_{} -k ../../../target/vk/leafs/vk", i + 1, i + 1))
                .current_dir("../circuits/app/proof_of_reserve/coins")
                .status()
                .expect("failed to execute command");

            assert!(status.success(), "Command return non-zero status");

            drop(permit);
        });

        tasks.push(task);
    }

    join_all(tasks).await;
}

fn tree_tomls(nodes: usize, vk_path: String, proof_path: String, level: usize) -> Result<()> {
    let chunks = (nodes + MAX_NODES_AMOUNT - 1) / MAX_NODES_AMOUNT;

    let vk = fs::read(vk_path.clone() + "/vk")?;
    let vk_hash = fs::read(vk_path + "/vk_hash")?;

    let mut vk_strings: Vec<String> = Vec::with_capacity(115);
    for byte in vk.chunks(32) {
        vk_strings.push("0x".to_owned() + &hex::encode(byte));
    }

    let key_hash = "0x".to_owned() + &hex::encode(&vk_hash);
    let zero_string = format!("0x{}", "0".repeat(64));
    let zero_proof = vec![zero_string.clone(); 508];
    let zero_pi = vec![zero_string; 65];

    for i in 0..chunks {
        let mut node_proofs = Vec::new();
        for j in 0..MAX_NODES_AMOUNT {
            if i * MAX_NODES_AMOUNT + j + 1 > nodes {
                node_proofs.push(NodeProof {
                    proof: zero_proof.clone(),
                    public_inputs: zero_pi.clone(),
                });
                continue;
            }

            let proof = fs::read(format!(
                "{}/proof_{}_{}/proof",
                proof_path,
                level,
                i * MAX_NODES_AMOUNT + j + 1
            ))?;
            let pi = fs::read(format!(
                "{}/proof_{}_{}/public_inputs",
                proof_path,
                level,
                i * MAX_NODES_AMOUNT + j + 1
            ))?;

            let mut proof_strings: Vec<String> = Vec::with_capacity(508);
            let mut pi_strings: Vec<String> = Vec::with_capacity(65);

            for byte in proof.chunks(32) {
                proof_strings.push("0x".to_owned() + &hex::encode(byte));
            }

            for byte in pi.chunks(32) {
                pi_strings.push("0x".to_owned() + &hex::encode(byte));
            }

            node_proofs.push(NodeProof {
                proof: proof_strings,
                public_inputs: pi_strings,
            });
        }

        let node_toml = NodeToml {
            verification_key: vk_strings.clone(),
            key_hash: key_hash.clone(),
            node_proofs,
            finalize_mr: i != 0,
        };

        let mut file = File::create(format!(
            "../circuits/app/proof_of_reserve/utxos_tree/provers/Prover_{}_{}.toml",
            level,
            i + 1
        ))?;
        file.write(toml::to_string(&node_toml)?.as_bytes())?;
    }

    Ok(())
}

async fn prove_nodes(mut chunks: usize) -> (String, u64) {
    if chunks == 1 {
        // Get output data
        let pi = fs::read("../circuits/target/coins/proofs/proof_0_1/public_inputs").unwrap();

        let mut idx = 1055;

        let mut mr = [0; 32];
        for i in 0..32 {
            mr[i] = pi[idx];
            idx += 32;
        }

        let mut amount = [0; 8];
        for i in 0..8 {
            amount[i] = pi[idx - (7 - i)];
        }

        return (hex::encode(mr), u64::from_be_bytes(amount));
    }

    let status = Command::new("bash")
        .arg("-c")
        .arg("nargo compile")
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

    tree_tomls(
        chunks,
        "../circuits/target/vk/leafs".to_string(),
        "../circuits/target/coins/proofs".to_string(),
        0,
    )
    .unwrap();

    // Async
    let semaphore = Arc::new(Semaphore::new(MAX_ASYNC_TASKS));

    let mut i = 0;
    loop {
        let mut tasks = Vec::new();
        chunks = (chunks + MAX_NODES_AMOUNT - 1) / MAX_NODES_AMOUNT;
        for j in 0..chunks {
            let permit = semaphore.clone().acquire_owned().await.unwrap();

            let task = tokio::spawn(async move {
                let status = Command::new("bash")
                    .arg("-c")
                    .arg(format!("nargo execute -p ./provers/Prover_{}_{}.toml ./tree/witness/utxos_tree_{}_{}.gz", i, j + 1, i, j + 1))
                    .current_dir("../circuits/app/proof_of_reserve/utxos_tree")
                    .status()
                    .expect("failed to execute command");

                assert!(status.success(), "Command return non-zero status");

                let status = Command::new("bash")
                    .arg("-c")
                    .arg(format!("bb prove -b ../../../target/utxos_tree.json -w ../../../target/tree/witness/utxos_tree_{}_{}.gz -o ../../../target/tree/proofs/proof_{}_{} -k ../../../target/vk/tree/vk", i, j + 1, i, j + 1))
                    .current_dir("../circuits/app/proof_of_reserve/utxos_tree")
                    .status()
                    .expect("failed to execute command");

                assert!(status.success(), "Command return non-zero status");
                drop(permit);
            });

            tasks.push(task);
        }

        join_all(tasks).await;

        if chunks <= 1 {
            break;
        }

        tree_tomls(
            chunks,
            "../circuits/target/vk/tree".to_string(),
            "../circuits/target/tree/proofs".to_string(),
            i,
        )
        .unwrap();
        i += 1;
    }

    // Get output data
    let pi = fs::read(format!(
        "../circuits/target/tree/proofs/proof_{}_1/public_inputs",
        i
    ))
    .unwrap();

    let mut idx = 1055;

    let mut mr = [0; 32];
    for i in 0..32 {
        mr[i] = pi[idx];
        idx += 32;
    }

    let mut amount = [0; 8];
    for i in 0..8 {
        amount[i] = pi[idx - (7 - i)];
    }

    (hex::encode(mr), u64::from_be_bytes(amount))
}

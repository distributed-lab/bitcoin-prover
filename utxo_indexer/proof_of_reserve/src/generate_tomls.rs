use std::{
    fs::{self, File},
    io::Write,
};

use anyhow::Result;
use serde::{Deserialize, Serialize};
use utxo_test_data_generator::test_data_gen::Utxo;

use crate::{MAX_COINS_DATABASE_AMOUNT, MAX_NODES_AMOUNT};

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

pub fn leafs_tomls(utxos: &[Utxo], message_hash: &[u8; 32]) -> Result<()> {
    let mut coins_database: Vec<CoinsDatabaseElement> = utxos
        .into_iter()
        .map(|e| {
            Ok(CoinsDatabaseElement {
                script_pub_key: hex::decode(&e.script_pub_key)?,
                amount: e.amount,
            })
        })
        .collect::<Result<Vec<_>>>()?;

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

    let mut own_utxos: Vec<Spending> = utxos
        .into_iter()
        .map(|e| {
            let mut witness = hex::decode(&e.witness)?;
            if witness.len() < 72 {
                witness.resize(72, 0);
            }

            let mut pub_key = Vec::from(hex::decode(&e.pub_key)?);
            if pub_key.len() < 65 {
                pub_key.resize(65, 0);
            }

            Ok(Spending {
                witness,
                pub_key: pub_key,
            })
        })
        .collect::<Result<Vec<_>>>()?;

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

pub fn tree_tomls(
    nodes: usize,
    vk_path: String,
    proof_path: String,
    proof_level: usize,
    prover_level: usize,
) -> Result<()> {
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
                proof_level,
                i * MAX_NODES_AMOUNT + j + 1
            ))?;
            let pi = fs::read(format!(
                "{}/proof_{}_{}/public_inputs",
                proof_path,
                proof_level,
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
            prover_level,
            i + 1
        ))?;
        file.write(toml::to_string(&node_toml)?.as_bytes())?;
    }

    Ok(())
}

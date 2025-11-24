use std::{fs, process::Command, sync::Arc};

use anyhow::{Ok, Result};
use futures::future::join_all;
use tokio::sync::Semaphore;

use crate::{MAX_ASYNC_TASKS, MAX_NODES_AMOUNT, generate_tomls::tree_tomls};

pub async fn prove_leafs(chunks: usize) -> Result<()> {
    let status = Command::new("bash")
        .arg("-c")
        .arg("nargo compile")
        .current_dir("../circuits/app/proof_of_reserve/coins")
        .status()
        .expect("failed to execute command");

    assert!(status.success(), "Command return non-zero status");

    fs::create_dir_all("../circuits/target/vk/leafs")?;
    fs::create_dir_all("../circuits/target/vk/tree")?;

    let status = Command::new("bash")
        .arg("-c")
        .arg("bb write_vk -b ../../../target/coins.json -o ../../../target/vk/leafs")
        .current_dir("../circuits/app/proof_of_reserve/coins")
        .status()
        .expect("failed to execute command");

    assert!(status.success(), "Command return non-zero status");

    fs::create_dir_all("../circuits/target/coins")?;

    // Async
    let semaphore = Arc::new(Semaphore::new(MAX_ASYNC_TASKS));
    let mut tasks = Vec::new();

    for i in 0..chunks {
        let permit = semaphore.clone().acquire_owned().await?;

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
    Ok(())
}

pub async fn prove_nodes(mut chunks: usize) -> Result<(String, u64)> {
    if chunks == 1 {
        // Get output data
        let pi = fs::read("../circuits/target/coins/proofs/proof_0_1/public_inputs")?;

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

        return Ok((hex::encode(mr), u64::from_be_bytes(amount)));
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
        0,
    )?;

    // Async
    let semaphore = Arc::new(Semaphore::new(MAX_ASYNC_TASKS));

    let mut i = 0;
    loop {
        let mut tasks = Vec::new();
        chunks = (chunks + MAX_NODES_AMOUNT - 1) / MAX_NODES_AMOUNT;
        for j in 0..chunks {
            let permit = semaphore.clone().acquire_owned().await?;

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
            i + 1,
        )?;
        i += 1;
    }

    // Get output data
    let pi = fs::read(format!(
        "../circuits/target/tree/proofs/proof_{}_1/public_inputs",
        i
    ))?;

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

    Ok((hex::encode(mr), u64::from_be_bytes(amount)))
}

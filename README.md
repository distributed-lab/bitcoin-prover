# wrapless-noir-prover

## Description

Bitcoin proofs

## Directory Structure
- `blocks/` – Contains the Noir circuit, artifacts, and necessary files for verifying the correctness of an SPV block chain.

- `generator_blocks/` – Python script that generate Prover.toml for the Noir project.

- `p2sh/` – Contains the Noir circuit, artifacts, and necessary files for p2sh proof generation.

- `generator_p2sh/` – Python script that generate Prover.toml and main.nr for the Noir project.

- `scripts` – Contains script to automate proof generation.

## Scripts

- `p2sh.sh` – automatic p2sh proof generation.

⚠️ **Warning:** Each generator has a `config.json` - make sure to edit it before running any scripts. All scripts should be run from the `wrapless-noir-prover/` directory.
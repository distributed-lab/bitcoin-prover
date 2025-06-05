# Wrapless Noir Prover

This project contains a collection of Noir circuits and their corresponding Rust implementations.

## Directory Structure

This structure separates concerns nicely:
- `app/` - Contains the core Noir code
- `crates/` - Contains Rust implementations
- `generators/` - Contains Python scripts for configuration generation
- `scripts/` - Contains shell scripts for execution orchestration
- `target/` - Contains build outputs and generated files

## Components

- `app/` – Contains Noir circuits and their dependencies
  - `blocks/` – Contains the blocks-related Noir code
  - `p2sh/` – Contains the P2SH (Pay-to-Script-Hash) related Noir code

- `crates/` – Contains Rust crates/libraries
  - `blocks/` – Rust implementation for blocks functionality

- `generators/` – Contains Python scripts for generating configuration files
  - `blocks/` – Python code to generate blocks-related configuration
  - `p2sh/` – Python code to generate P2SH-related configuration

- `scripts/` – Contains shell scripts for executing proofs
  - `blocks.sh` – Script to run the blocks proof generation and verification
  - `p2sh.sh` – Script to run the P2SH proof generation and verification

- `target/` – Output directory for generated files
  - Contains subdirectories for each proof type (e.g., `blocks_bin/`, `p2sh_bin/`)
  - Stores intermediate files like:
    - `.json` files (circuit descriptions)
    - `.gz` files (witness data)
    - `vk` (verification keys)
    - `proof` (generated proofs)

## Workflow

The typical workflow is:
1. Python generators create configuration files
2. Noir code in `app/` is compiled and executed
3. Proofs are generated and verified using the `bb` tool
4. All outputs are stored in the `target/` directory

## Requirements

- [Noir](https://noir-lang.org/)
- [Rust](https://www.rust-lang.org/)
- Python 3
- [bb](https://github.com/zkcrypto/bb) tool

## Usage

To run the blocks proof:
```bash
./scripts/blocks.sh
```

To run the P2SH proof:
```bash
./scripts/p2sh.sh
```

⚠️ **Warning:** Each generator has a `config.json` - make sure to edit it before running any scripts. All scripts should be run from the `wrapless-noir-prover/` directory.
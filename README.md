# Bitcoin prover

This project contains a collection of Noir circuits and their corresponding Noir implementations.

## Directory Structure

This structure separates concerns nicely:
- `app/` - Contains the core Noir code
- `crates/` - Contains Noir implementations
- `generators/` - Contains Python scripts for configuration generation
- `scripts/` - Contains shell scripts for execution orchestration
- `target/` - Contains build outputs and generated files

## Components

- `app/` – Contains Noir circuits and their dependencies

- `crates/` – Contains Noir crates/libraries
  - `blocks/` – Noir implementation for blocks functionality
  - `bvm/` – Noir implementation for bitcoin stack functionality
  - `script/` – Noir implementation for bitcoin script execution
  - `utils` – Noir utils
  - `crypto` – Noir implementation for crypto algorithms
  - `sign` – Noir implementation for bitcoin tx serialization

- `generators/` – Contains Python scripts for generating noir files

- `scripts/` – Contains shell scripts for executing proofs

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
- Python 3
- [bb](https://github.com/zkcrypto/bb) tool

## Usage

To run the blocks proof (generators/blocks/config.json - edit it before using):
```bash
./scripts/blocks.sh
```

To run the any spending proof:
```bash
python3 -m generators.general.main
```

⚠️ **Warning:** General generator (generators/general) uses a `config.json` - make sure to edit it before running the spending script. All scripts should be run from the project root directory. For usage instructions, see the [general generator README](generators/general/README.md)


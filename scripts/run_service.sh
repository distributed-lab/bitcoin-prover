#!/bin/bash

# Exit on error
set -e  

# Create virtual environment and install required packages
python3 -m venv ./generators/blocks/venv
source ./generators/blocks/venv/bin/activate
pip3 install electrum_client fastapi uvicorn

# Generate Prover.toml
uvicorn service.main:app --reload --host localhost --port 8000

# Deactivate venv
deactivate
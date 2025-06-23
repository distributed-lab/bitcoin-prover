#!/usr/bin/env python3
"""
Transaction data extractor for block explorer JSON data.
Extracts raw transaction hex from JSON data obtained from block explorers.
"""

import json
import sys
from typing import Dict, Any
import hashlib


def load_tx_json(file_path: str) -> Dict[str, Any]:
    """
    Load transaction JSON data from a file.
    
    Args:
        file_path: Path to the JSON file containing transaction data
        
    Returns:
        Dictionary containing the transaction data
        
    Raises:
        FileNotFoundError: If the file doesn't exist
        json.JSONDecodeError: If the file contains invalid JSON
    """
    try:
        with open(file_path, 'r') as f:
            return json.load(f)
    except FileNotFoundError:
        raise FileNotFoundError(f"Transaction file not found: {file_path}")
    except json.JSONDecodeError as e:
        raise json.JSONDecodeError(f"Invalid JSON in {file_path}: {e}")


def encode_varint(value: int) -> str:
    """
    Encode a value as a Bitcoin varint.
    
    Args:
        value: Integer value to encode
        
    Returns:
        Hex string of the varint
    """
    if value < 0xfd:
        return f"{value:02x}"
    elif value <= 0xffff:
        return f"fd{value:04x}"
    elif value <= 0xffffffff:
        return f"fe{value:08x}"
    else:
        return f"ff{value:016x}"


def reconstruct_tx_hex(tx_data: Dict[str, Any]) -> str:
    """
    Reconstruct raw transaction hex from JSON components.
    
    This is a simplified reconstruction that may not work for all transaction types.
    For complex transactions (especially those with witness data), you may need
    more sophisticated reconstruction logic.
    
    Args:
        tx_data: Dictionary containing transaction data
        
    Returns:
        Reconstructed transaction hex string
        
    Raises:
        ValueError: If required transaction components are missing
    """
    # Check for required fields
    required_fields = ['version', 'inputs', 'outputs', 'locktime']
    for field in required_fields:
        if field not in tx_data:
            raise ValueError(f"Missing required field: {field}")
    
    # Start building the hex
    hex_parts = []
    
    # Version (4 bytes, little-endian)
    version = tx_data['version']
    # Convert to little-endian hex
    version_bytes = version.to_bytes(4, byteorder='little')
    hex_parts.append(version_bytes.hex())
    
    # Input count and inputs
    inputs = tx_data['inputs']
    hex_parts.append(encode_varint(len(inputs)))  # Proper varint for input count
    
    for inp in inputs:
        # Previous txid (32 bytes, little-endian)
        txid = inp['txid']
        # Reverse byte order for little-endian
        txid_bytes = bytes.fromhex(txid)
        hex_parts.append(txid_bytes[::-1].hex())
        
        # Output index (4 bytes, little-endian)
        output_index = inp['output']
        output_bytes = output_index.to_bytes(4, byteorder='little')
        hex_parts.append(output_bytes.hex())
        
        # Script length and script
        sigscript = inp.get('sigscript', '')
        script_len = len(sigscript) // 2  # Convert hex to byte length
        hex_parts.append(f"{script_len:02x}")
        hex_parts.append(sigscript)
        
        # Sequence (4 bytes, little-endian)
        sequence = inp.get('sequence', 0xffffffff)
        sequence_bytes = sequence.to_bytes(4, byteorder='little')
        hex_parts.append(sequence_bytes.hex())
    
    # Output count and outputs
    outputs = tx_data['outputs']
    hex_parts.append(encode_varint(len(outputs)))  # Proper varint for output count
    
    for out in outputs:
        # Value (8 bytes, little-endian)
        value = out['value']
        value_bytes = value.to_bytes(8, byteorder='little')
        hex_parts.append(value_bytes.hex())
        
        # Script length and script
        pkscript = out['pkscript']
        script_len = len(pkscript) // 2  # Convert hex to byte length
        hex_parts.append(f"{script_len:02x}")
        hex_parts.append(pkscript)
    
    # Locktime (4 bytes, little-endian)
    locktime = tx_data['locktime']
    locktime_bytes = locktime.to_bytes(4, byteorder='little')
    hex_parts.append(locktime_bytes.hex())
    
    return ''.join(hex_parts)


def get_raw_transaction_hex(tx_data: Dict[str, Any]) -> str:
    """
    Get raw transaction hex from JSON data by reconstructing from components.
    
    Args:
        tx_data: Dictionary containing transaction data
        
    Returns:
        Raw transaction hex string
        
    Raises:
        ValueError: If hex cannot be reconstructed
    """
    try:
        return reconstruct_tx_hex(tx_data)
    except Exception as e:
        raise ValueError(f"Could not reconstruct transaction hex: {e}")


def calculate_txid_from_hex(raw_hex: str) -> str:
    """
    Calculate the Bitcoin transaction ID (txid) from the raw transaction hex.
    Args:
        raw_hex: Raw transaction hex string
    Returns:
        txid as a hex string (little-endian)
    """
    tx_bytes = bytes.fromhex(raw_hex)
    hash1 = hashlib.sha256(tx_bytes).digest()
    hash2 = hashlib.sha256(hash1).digest()
    # Return as little-endian hex string
    return hash2[::-1].hex()


def main():
    """
    Main function to process transaction JSON and extract raw hex.
    """
    if len(sys.argv) != 2:
        print("Usage: python gen.py <tx_json_file>")
        print("Example: python gen.py tx.json")
        sys.exit(1)
    
    json_file = sys.argv[1]
    
    try:
        # Load transaction data
        tx_data = load_tx_json(json_file)
        
        # Extract raw transaction hex
        raw_hex = get_raw_transaction_hex(tx_data)
        
        print(f"Raw transaction hex:")
        print(raw_hex)
        
        # Calculate and print txid
        calculated_txid = calculate_txid_from_hex(raw_hex)
        print(f"\nCalculated TXID: {calculated_txid}")
        print(f"Expected TXID:   {tx_data.get('txid', 'Unknown')}")
        
        # Also print some basic info
        print(f"\nTransaction info:")
        print(f"TXID: {tx_data.get('txid', 'Unknown')}")
        print(f"Size: {tx_data.get('size', 'Unknown')} bytes")
        print(f"Inputs: {len(tx_data.get('inputs', []))}")
        print(f"Outputs: {len(tx_data.get('outputs', []))}")
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()

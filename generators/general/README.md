# General generator

Each spending type requires diferend config fields.

If some fields are not applicable, leave them empty — do not remove them.

## Common configuration parameters

All spending types must include the following:

- `tx` - Contains current transaction hex
- `input_to_sign` - Contains index of input that will spend prev tx output

## P2PKH/P2WPKH

- `pub_key` - Contains the public key whose hash was inserted into `script_pub_key`
- `signature` - Contains the signature that proves ownership of the corresponding private key

## P2MS, P2SH, P2SH-P2WPKH, P2SH-P2WSH

- `script_sig` - Contains input data and/or corresponding script to spend output

## P2TR, P2WSH

These types do not require any additional configuration fields.

All necessary data must be included in the witness section of the `tx` hex.
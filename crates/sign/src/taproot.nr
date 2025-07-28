use crate::compact_size;
use crate::transaction::{Output, PositionField, Transaction};
use crypto::schnorr::tagged_hash;
use utils::convert::{
    bytes_to_hex, hex_to_bytes, reverse_bytes, sha256_to_le_bytes, u32_to_le_bytes,
};

fn parse_outputs<let OUTPUT_SIZE: u32, let OUTPUT_COUNT: u32>(
    data: [u8; OUTPUT_SIZE],
) -> [Output; OUTPUT_COUNT] {
    let mut cur_pos = 0;
    let mut outputs: [Output; OUTPUT_COUNT] = [Output::default(); OUTPUT_COUNT];
    for i in 0..OUTPUT_COUNT {
        let amount = PositionField { offset: cur_pos, size: 8 };
        cur_pos += 8;

        let script_pub_key_size = compact_size::get_compact_size(data, cur_pos);
        cur_pos += script_pub_key_size.size;

        let script_pub_key_size_u32 = compact_size::compact_size_to_u32(data, script_pub_key_size);
        let script_pub_key = PositionField { offset: cur_pos, size: script_pub_key_size_u32 };
        cur_pos += script_pub_key_size_u32;

        outputs[i] = Output { amount, script_pub_key_size, script_pub_key };
    }

    outputs
}

fn prepare_preimage_hash_for_sighash_all<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let UTXO_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    extension_flag: u8,
    unspent_outputs: [Output; INPUT_COUNT],
    unspent_outputs_data: [u8; UTXO_SIZE],
    is_annex_present: bool,
) -> [u8; 1 + 1 + 4 + 4 + 32 + 32 + 32 + 32 + 32 + 1 + 4] {
    let mut data = [0; 1 + 1 + 4 + 4 + 32 + 32 + 32 + 32 + 32 + 1 + 4];
    let mut cur_pos = 0;
    let mut hash_buffer = [0; 32];
    // epoch = 0
    cur_pos += 1;

    // hash type
    data[cur_pos] = 1;
    cur_pos += 1;

    // Version
    for i in 0..4 {
        data[cur_pos] = transaction.data[i];
        cur_pos += 1;
    }

    // Lock time
    let transaction_locktime_offset = transaction.lock_time.offset;
    for i in 0..4 {
        data[cur_pos] = transaction.data[transaction_locktime_offset + i];
        cur_pos += 1;
    }

    // Inputs ((txid, vout) + (txid, vout) + ...) hash
    let mut preimage_inputs = [0; INPUT_COUNT * (32 + 4)];
    for i in 0..INPUT_COUNT {
        let transaction_txid_offset = transaction.inputs[i].txid.offset;
        for j in 0..32 {
            preimage_inputs[i * (32 + 4) + j] = transaction.data[transaction_txid_offset + j];
        }

        let transaction_vout_offset = transaction.inputs[i].vout.offset;
        for j in 0..4 {
            preimage_inputs[i * (32 + 4) + 32 + j] = transaction.data[transaction_vout_offset + j];
        }
    }

    hash_buffer = sha256::digest(preimage_inputs);
    for i in 0..32 {
        data[cur_pos] = hash_buffer[i];
        cur_pos += 1;
    }

    // amount of all utxos
    let mut preimage_amounts = [0; INPUT_COUNT * 8];
    for i in 0..INPUT_COUNT {
        let transaction_output_amount_offset = unspent_outputs[i].amount.offset;
        for j in 0..8 {
            preimage_amounts[i * 8 + j] =
                unspent_outputs_data[transaction_output_amount_offset + j];
        }
    }

    hash_buffer = sha256::digest(preimage_amounts);
    for i in 0..32 {
        data[cur_pos] = hash_buffer[i];
        cur_pos += 1;
    }

    // script pubkeys of utxo
    let mut preimage_output_script = [0; UTXO_SIZE - 8 * INPUT_COUNT];
    let mut current_transaction_offset = unspent_outputs[0].script_pub_key_size.offset;
    let mut next_output = 1;

    for i in 0..(UTXO_SIZE - 8 * INPUT_COUNT) {
        if (next_output != INPUT_COUNT) {
            if (current_transaction_offset == unspent_outputs[next_output].amount.offset) {
                current_transaction_offset =
                    unspent_outputs[next_output].script_pub_key_size.offset;
                next_output += 1;
            }
        }
        if current_transaction_offset < UTXO_SIZE {
            preimage_output_script[i] = unspent_outputs_data[current_transaction_offset];
            current_transaction_offset += 1;
        }
    }

    hash_buffer = sha256::digest(preimage_output_script);
    for i in 0..32 {
        data[cur_pos] = hash_buffer[i];
        cur_pos += 1;
    }

    // Sequences (sequence + sequence + ...) hash
    let mut preimage_sequences = [0; INPUT_COUNT * 4];
    for i in 0..INPUT_COUNT {
        let transaction_sequence_offset = transaction.inputs[i].sequence.offset;
        for j in 0..4 {
            preimage_sequences[i * 4 + j] = transaction.data[transaction_sequence_offset + j];
        }
    }

    hash_buffer = sha256::digest(preimage_sequences);
    for i in 0..32 {
        data[cur_pos] = hash_buffer[i];
        cur_pos += 1;
    }

    // Outputs
    let mut preimage_outputs = [0; OUTPUT_SIZE - OUTPUT_COUNT_LEN];

    let transaction_output_offset = transaction.output_count.offset + transaction.output_count.size;
    for i in 0..(OUTPUT_SIZE - OUTPUT_COUNT_LEN) {
        preimage_outputs[i] = transaction.data[transaction_output_offset + i];
    }

    hash_buffer = sha256::digest(preimage_outputs);
    for i in 0..32 {
        data[cur_pos] = hash_buffer[i];
        cur_pos += 1;
    }

    //spend type
    assert(extension_flag < 127);
    data[cur_pos] = extension_flag * 2;
    if is_annex_present {
        data[cur_pos] += 1;
    }
    cur_pos += 1;

    // vin of input to sign
    let input_index = u32_to_le_bytes(input_to_sign);
    for i in 0..4 {
        data[cur_pos] = input_index[i];
        cur_pos += 1;
    }

    assert(cur_pos == 1 + 1 + 4 + 4 + 32 + 32 + 32 + 32 + 32 + 1 + 4);

    data
}

fn serialize_p2tr_sighash_all<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let UTXO_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    extension_flag: u8,
    unspent_outputs: [Output; INPUT_COUNT],
    unspent_outputs_data: [u8; UTXO_SIZE],
    is_annex_present: bool,
    leaf_script_hash: Option<[u8; 32]>,
) -> [u8; 32] {
    let preimage = prepare_preimage_hash_for_sighash_all(
        transaction,
        input_to_sign,
        extension_flag,
        unspent_outputs,
        unspent_outputs_data,
        is_annex_present,
    );
    let mut hash = [0 as u8; 32];

    if leaf_script_hash.is_none() {
        hash = tagged_hash(preimage, "TapSighash".as_bytes());
    } else {
        let leaf_script_hash_unwrap = leaf_script_hash.unwrap();

        hash = tagged_hash(
            preimage
                .as_slice()
                .append(leaf_script_hash_unwrap)
                .append([0])
                .append([0xff, 0xff, 0xff, 0xff])
                .as_array::<175 + 37>(),
            "TapSighash".as_bytes(),
        );
    }
    hash
}

fn prepare_preimage_hash_for_sighash_all_anyonecanpay<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let UTXO_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    extension_flag: u8,
    utxo_data: [u8; 8 + 1 + 34],
    is_annex_present: bool,
) -> [u8;  1 + 1 + 4 + 4 + 32 + 1 + 36 + 8 + 35 + 4] {
    let mut data = [0; 1 + 1 + 4 + 4 + 32 + 1 + 36 + 8 + 35 + 4];
    let mut cur_pos = 0;
    let mut hash_buffer = [0; 32];
    // epoch = 0
    cur_pos += 1;

    // hash type
    data[cur_pos] = 0x81;
    cur_pos += 1;

    // Version
    for i in 0..4 {
        data[cur_pos] = transaction.data[i];
        cur_pos += 1;
    }

    // Lock time
    let transaction_locktime_offset = transaction.lock_time.offset;
    for i in 0..4 {
        data[cur_pos] = transaction.data[transaction_locktime_offset + i];
        cur_pos += 1;
    }
    
    // Outputs
    let mut preimage_outputs = [0; OUTPUT_SIZE - OUTPUT_COUNT_LEN];

    let transaction_output_offset = transaction.output_count.offset + transaction.output_count.size;
    for i in 0..(OUTPUT_SIZE - OUTPUT_COUNT_LEN) {
        preimage_outputs[i] = transaction.data[transaction_output_offset + i];
    }

    hash_buffer = sha256::digest(preimage_outputs);
    for i in 0..32 {
        data[cur_pos] = hash_buffer[i];
        cur_pos += 1;
    }

    //spend type
    assert(extension_flag < 127);
    data[cur_pos] = extension_flag * 2;
    if is_annex_present {
        data[cur_pos] += 1;
    }
    cur_pos += 1;

    // txid, vout
    let transaction_txid_offset = transaction.inputs[input_to_sign].txid.offset;
    for j in 0..32 {
        data[cur_pos] = transaction.data[transaction_txid_offset + j];
        cur_pos += 1;
    }

    let transaction_vout_offset = transaction.inputs[input_to_sign].vout.offset;
    for j in 0..4 {
        data[cur_pos] = transaction.data[transaction_vout_offset + j];
        cur_pos += 1;
    }

    // amount of utxo
    for i in 0..8 {
        data[cur_pos] = utxo_data[i];
        cur_pos += 1;
    }

    // script pubkey of utxo
    for i in 0..35 {
        data[cur_pos] = utxo_data[i + 8];
        cur_pos += 1;
    }

    // Sequence
    let transaction_sequence_offset = transaction.inputs[input_to_sign].sequence.offset;
    for i in 0..4 {
        data[cur_pos] = transaction.data[transaction_sequence_offset + i];
        cur_pos += 1;
    }

    assert(cur_pos == 1 + 1 + 4 + 4 + 32 + 1 + 36 + 8 + 35 + 4);

    data
}

fn serialize_p2tr_sighash_all_anyonecanpay<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let UTXO_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    extension_flag: u8,
    utxo_data: [u8; 8 + 1 + 34],
    is_annex_present: bool,
    leaf_script_hash: Option<[u8; 32]>,
) -> [u8; 32] {
    let preimage = prepare_preimage_hash_for_sighash_all_anyonecanpay(
        transaction,
        input_to_sign,
        extension_flag,
        utxo_data,
        is_annex_present,
    );
    let mut hash = [0 as u8; 32];

    if leaf_script_hash.is_none() {
        hash = tagged_hash(preimage, "TapSighash".as_bytes());
    } else {
        let leaf_script_hash_unwrap = leaf_script_hash.unwrap();
        hash = tagged_hash(
            preimage
                .as_slice()
                .append(leaf_script_hash_unwrap)
                .append([0])
                .append([0xff, 0xff, 0xff, 0xff])
                .as_array::<126 + 37>(),
            "TapSighash".as_bytes(),
        );
    }
    hash
}

fn prepare_preimage_hash_for_sighash_none<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let UTXO_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    extension_flag: u8,
    unspent_outputs: [Output; INPUT_COUNT],
    unspent_outputs_data: [u8; UTXO_SIZE],
    is_annex_present: bool,
) -> [u8; 1 + 1 + 4 + 4 + 32 + 32 + 32 + 32 + 1 + 4] {
    let mut data = [0; 1 + 1 + 4 + 4 + 32 + 32 + 32 + 32 + 1 + 4];
    let mut cur_pos = 0;
    let mut hash_buffer = [0; 32];
    // epoch = 0
    cur_pos += 1;

    // hash type
    data[cur_pos] = 2;
    cur_pos += 1;

    // Version
    for i in 0..4 {
        data[cur_pos] = transaction.data[i];
        cur_pos += 1;
    }

    // Lock time
    let transaction_locktime_offset = transaction.lock_time.offset;
    for i in 0..4 {
        data[cur_pos] = transaction.data[transaction_locktime_offset + i];
        cur_pos += 1;
    }

    // Inputs ((txid, vout) + (txid, vout) + ...) hash
    let mut preimage_inputs = [0; INPUT_COUNT * (32 + 4)];
    for i in 0..INPUT_COUNT {
        let transaction_txid_offset = transaction.inputs[i].txid.offset;
        for j in 0..32 {
            preimage_inputs[i * (32 + 4) + j] = transaction.data[transaction_txid_offset + j];
        }

        let transaction_vout_offset = transaction.inputs[i].vout.offset;
        for j in 0..4 {
            preimage_inputs[i * (32 + 4) + 32 + j] = transaction.data[transaction_vout_offset + j];
        }
    }

    hash_buffer = sha256::digest(preimage_inputs);
    for i in 0..32 {
        data[cur_pos] = hash_buffer[i];
        cur_pos += 1;
    }

    // amount of all utxos
    let mut preimage_amounts = [0; INPUT_COUNT * 8];
    for i in 0..INPUT_COUNT {
        let transaction_output_amount_offset = unspent_outputs[i].amount.offset;
        for j in 0..8 {
            preimage_amounts[i * 8 + j] =
                unspent_outputs_data[transaction_output_amount_offset + j];
        }
    }

    hash_buffer = sha256::digest(preimage_amounts);
    for i in 0..32 {
        data[cur_pos] = hash_buffer[i];
        cur_pos += 1;
    }

    // script pubkeys of utxo
    let mut preimage_output_script = [0; UTXO_SIZE - 8 * INPUT_COUNT];
    let mut current_transaction_offset = unspent_outputs[0].script_pub_key_size.offset;
    let mut next_output = 1;

    for i in 0..(UTXO_SIZE - 8 * INPUT_COUNT) {
        if (next_output != INPUT_COUNT) {
            if (current_transaction_offset == unspent_outputs[next_output].amount.offset) {
                current_transaction_offset =
                    unspent_outputs[next_output].script_pub_key_size.offset;
                next_output += 1;
            }
        }
        if current_transaction_offset < UTXO_SIZE {
            preimage_output_script[i] = unspent_outputs_data[current_transaction_offset];
            current_transaction_offset += 1;
        }
    }

    hash_buffer = sha256::digest(preimage_output_script);
    for i in 0..32 {
        data[cur_pos] = hash_buffer[i];
        cur_pos += 1;
    }

    // Sequences (sequence + sequence + ...) hash
    let mut preimage_sequences = [0; INPUT_COUNT * 4];
    for i in 0..INPUT_COUNT {
        let transaction_sequence_offset = transaction.inputs[i].sequence.offset;
        for j in 0..4 {
            preimage_sequences[i * 4 + j] = transaction.data[transaction_sequence_offset + j];
        }
    }

    hash_buffer = sha256::digest(preimage_sequences);
    for i in 0..32 {
        data[cur_pos] = hash_buffer[i];
        cur_pos += 1;
    }

    //spend type
    assert(extension_flag < 127);
    data[cur_pos] = extension_flag * 2;
    if is_annex_present {
        data[cur_pos] += 1;
    }
    cur_pos += 1;

    // vin of input to sign
    let input_index = u32_to_le_bytes(input_to_sign);
    for i in 0..4 {
        data[cur_pos] = input_index[i];
        cur_pos += 1;
    }

    assert(cur_pos == 1 + 1 + 4 + 4 + 32 + 32 + 32 + 32 + 1 + 4);

    data
}

fn serialize_p2tr_sighash_none<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let UTXO_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    extension_flag: u8,
    unspent_outputs: [Output; INPUT_COUNT],
    unspent_outputs_data: [u8; UTXO_SIZE],
    is_annex_present: bool,
    leaf_script_hash: Option<[u8; 32]>,
) -> [u8; 32] {
    let preimage = prepare_preimage_hash_for_sighash_none(
        transaction,
        input_to_sign,
        extension_flag,
        unspent_outputs,
        unspent_outputs_data,
        is_annex_present,
    );
    let mut hash = [0 as u8; 32];

    if leaf_script_hash.is_none() {
        hash = tagged_hash(preimage, "TapSighash".as_bytes());
    } else {
        let leaf_script_hash_unwrap = leaf_script_hash.unwrap();

        hash = tagged_hash(
            preimage
                .as_slice()
                .append(leaf_script_hash_unwrap)
                .append([0])
                .append([0xff, 0xff, 0xff, 0xff])
                .as_array::<143 + 37>(),
            "TapSighash".as_bytes(),
        );
    }
    hash
}

fn prepare_preimage_hash_for_sighash_none_anyonecanpay<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let UTXO_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    extension_flag: u8,
    utxo_data: [u8; 8 + 1 + 34],
    is_annex_present: bool,
) -> [u8;  1 + 1 + 4 + 4 + 1 + 36 + 8 + 35 + 4] {
    let mut data = [0; 1 + 1 + 4 + 4 + 1 + 36 + 8 + 35 + 4];
    let mut cur_pos = 0;
    let mut hash_buffer = [0; 32];
    // epoch = 0
    cur_pos += 1;

    // hash type
    data[cur_pos] = 0x82;
    cur_pos += 1;

    // Version
    for i in 0..4 {
        data[cur_pos] = transaction.data[i];
        cur_pos += 1;
    }

    // Lock time
    let transaction_locktime_offset = transaction.lock_time.offset;
    for i in 0..4 {
        data[cur_pos] = transaction.data[transaction_locktime_offset + i];
        cur_pos += 1;
    }
    
    //spend type
    assert(extension_flag < 127);
    data[cur_pos] = extension_flag * 2;
    if is_annex_present {
        data[cur_pos] += 1;
    }
    cur_pos += 1;

    // txid, vout
    let transaction_txid_offset = transaction.inputs[input_to_sign].txid.offset;
    for j in 0..32 {
        data[cur_pos] = transaction.data[transaction_txid_offset + j];
        cur_pos += 1;
    }

    let transaction_vout_offset = transaction.inputs[input_to_sign].vout.offset;
    for j in 0..4 {
        data[cur_pos] = transaction.data[transaction_vout_offset + j];
        cur_pos += 1;
    }

    // amount of utxo
    for i in 0..8 {
        data[cur_pos] = utxo_data[i];
        cur_pos += 1;
    }

    // script pubkey of utxo
    for i in 0..35 {
        data[cur_pos] = utxo_data[i + 8];
        cur_pos += 1;
    }

    // Sequence
    let transaction_sequence_offset = transaction.inputs[input_to_sign].sequence.offset;
    for i in 0..4 {
        data[cur_pos] = transaction.data[transaction_sequence_offset + i];
        cur_pos += 1;
    }

    assert(cur_pos == 1 + 1 + 4 + 4 + 1 + 36 + 8 + 35 + 4);

    data
}

fn serialize_p2tr_sighash_none_anyonecanpay<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let UTXO_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    extension_flag: u8,
    utxo_data: [u8; 8 + 1 + 34],
    is_annex_present: bool,
    leaf_script_hash: Option<[u8; 32]>,
) -> [u8; 32] {
    let preimage = prepare_preimage_hash_for_sighash_none_anyonecanpay(
        transaction,
        input_to_sign,
        extension_flag,
        utxo_data,
        is_annex_present,
    );
    let mut hash = [0 as u8; 32];

    if leaf_script_hash.is_none() {
        hash = tagged_hash(preimage, "TapSighash".as_bytes());
    } else {
        let leaf_script_hash_unwrap = leaf_script_hash.unwrap();
        hash = tagged_hash(
            preimage
                .as_slice()
                .append(leaf_script_hash_unwrap)
                .append([0])
                .append([0xff, 0xff, 0xff, 0xff])
                .as_array::<94 + 37>(),
            "TapSighash".as_bytes(),
        );
    }
    hash
}


#[test]
fn test_taproot_sighash_all() {
    let hex_string = "020000000001023cfe8b95d22502698fd98837f83d8d4be31ee3eddd9d1ab1a95654c64604c4d10100000000feffffff3cfe8b95d22502698fd98837f83d8d4be31ee3eddd9d1ab1a95654c64604c4d10000000000ffffffff023acf00000000000017a914453acd285e0b84ce01be507e1de19ebc2494c28d8734a8cc2e0000000017a9146fc16fc2550e819d837d5cc5b37237642ab131978701430141b693a0797b24bae12ed0516a2f5ba765618dca89b75e498ba5b745b71644362298a45ca39230d10a02ee6290a91cebf9839600f7e35158a447ea182ea0e022ae010188034101769105cbcbdcaaee5e58cd201ba3152477fda31410df8b91b4aee2c4864c7700615efb425e002f146a39ca0a4f2924566762d9213bd33f825fad83977fba7f0122206d4ddc0e47d2e8f82cbe2fc2d0d749e7bd3338112cecdc76d8f831ae6620dbe0ac21c0924c163b385af7093440184af6fd6244936d1288cbb41cc3812286d3f83a33294fd80900";
    let bytes = hex_to_bytes(hex_string);
    let transaction = Transaction::<365, 2, 1, 83, 2, 1, 65, 1, 207>::new(bytes, true);

    let utxo_data: [u8; 86] = hex_to_bytes(
        "983a0000000000002251203daaca9b82a51aca960c1491588246029d7e0fc49e0abdbcc8fd17574be5c74b983a3400000000002251200f0c8db753acbd17343a39c2f3f4e35e4be6da749f9e35137ab220e7b238a667",
    );
    let outputs = parse_outputs::<86, 2>(utxo_data);

    assert(
        bytes_to_hex(serialize_p2tr_sighash_all(
            transaction,
            0,
            0,
            outputs,
            utxo_data,
            false,
            Option::none(),
        ))
            == "ac18154e3a7c525049208b66716ca4de989db23e338fc6552d0dec29cc65b777",
    );
}

#[test]
fn test_taproot_sighash_all_with_leaf() {
    let hex_string = "020000000001023cfe8b95d22502698fd98837f83d8d4be31ee3eddd9d1ab1a95654c64604c4d10100000000feffffff3cfe8b95d22502698fd98837f83d8d4be31ee3eddd9d1ab1a95654c64604c4d10000000000ffffffff023acf00000000000017a914453acd285e0b84ce01be507e1de19ebc2494c28d8734a8cc2e0000000017a9146fc16fc2550e819d837d5cc5b37237642ab131978701430141b693a0797b24bae12ed0516a2f5ba765618dca89b75e498ba5b745b71644362298a45ca39230d10a02ee6290a91cebf9839600f7e35158a447ea182ea0e022ae010188034101769105cbcbdcaaee5e58cd201ba3152477fda31410df8b91b4aee2c4864c7700615efb425e002f146a39ca0a4f2924566762d9213bd33f825fad83977fba7f0122206d4ddc0e47d2e8f82cbe2fc2d0d749e7bd3338112cecdc76d8f831ae6620dbe0ac21c0924c163b385af7093440184af6fd6244936d1288cbb41cc3812286d3f83a33294fd80900";
    let bytes = hex_to_bytes(hex_string);
    let transaction = Transaction::<365, 2, 1, 83, 2, 1, 65, 1, 207>::new(bytes, true);

    let utxo_data: [u8; 86] = hex_to_bytes(
        "983a0000000000002251203daaca9b82a51aca960c1491588246029d7e0fc49e0abdbcc8fd17574be5c74b983a3400000000002251200f0c8db753acbd17343a39c2f3f4e35e4be6da749f9e35137ab220e7b238a667",
    );
    let outputs = parse_outputs::<86, 2>(utxo_data);
    let leaf_script = hex_to_bytes("c022206d4ddc0e47d2e8f82cbe2fc2d0d749e7bd3338112cecdc76d8f831ae6620dbe0ac");
    let leaf_script_hash = tagged_hash(leaf_script, "TapLeaf".as_bytes());
    assert(
        bytes_to_hex(serialize_p2tr_sighash_all(
            transaction,
            0,
            1,
            outputs,
            utxo_data,
            false,
            Option::some(leaf_script_hash),
        ))
            == "f161900a3d32a400664b66c4331fe8f51ce8edfaabad562ebb34c03a10c2cf3e",
    );
}

#[test]
fn test_taproot_sighash_all_anyonecanpay() {
    let hex_string = "020000000001023cfe8b95d22502698fd98837f83d8d4be31ee3eddd9d1ab1a95654c64604c4d10100000000feffffff3cfe8b95d22502698fd98837f83d8d4be31ee3eddd9d1ab1a95654c64604c4d10000000000ffffffff023acf00000000000017a914453acd285e0b84ce01be507e1de19ebc2494c28d8734a8cc2e0000000017a9146fc16fc2550e819d837d5cc5b37237642ab131978701430141b693a0797b24bae12ed0516a2f5ba765618dca89b75e498ba5b745b71644362298a45ca39230d10a02ee6290a91cebf9839600f7e35158a447ea182ea0e022ae010188034101769105cbcbdcaaee5e58cd201ba3152477fda31410df8b91b4aee2c4864c7700615efb425e002f146a39ca0a4f2924566762d9213bd33f825fad83977fba7f0122206d4ddc0e47d2e8f82cbe2fc2d0d749e7bd3338112cecdc76d8f831ae6620dbe0ac21c0924c163b385af7093440184af6fd6244936d1288cbb41cc3812286d3f83a33294fd80900";
    let bytes = hex_to_bytes(hex_string);
    let transaction = Transaction::<365, 2, 1, 83, 2, 1, 65, 1, 207>::new(bytes, true);

    let utxo = hex_to_bytes("983a3400000000002251200f0c8db753acbd17343a39c2f3f4e35e4be6da749f9e35137ab220e7b238a667");

    assert(
        bytes_to_hex(serialize_p2tr_sighash_all_anyonecanpay(
            transaction,
            1,
            0,
            utxo,
            false,
            Option::none(),
        ))
            == "77ad0517599d8f90722ae3b0bdd3bd3c9f40c28dcf5f1280a8083af3b5a70245",
    );
}

#[test]
fn test_taproot_sighash_all_anyonecanpay_with_leaf() {
    let hex_string = "020000000001023cfe8b95d22502698fd98837f83d8d4be31ee3eddd9d1ab1a95654c64604c4d10100000000feffffff3cfe8b95d22502698fd98837f83d8d4be31ee3eddd9d1ab1a95654c64604c4d10000000000ffffffff023acf00000000000017a914453acd285e0b84ce01be507e1de19ebc2494c28d8734a8cc2e0000000017a9146fc16fc2550e819d837d5cc5b37237642ab131978701430141b693a0797b24bae12ed0516a2f5ba765618dca89b75e498ba5b745b71644362298a45ca39230d10a02ee6290a91cebf9839600f7e35158a447ea182ea0e022ae010188034101769105cbcbdcaaee5e58cd201ba3152477fda31410df8b91b4aee2c4864c7700615efb425e002f146a39ca0a4f2924566762d9213bd33f825fad83977fba7f0122206d4ddc0e47d2e8f82cbe2fc2d0d749e7bd3338112cecdc76d8f831ae6620dbe0ac21c0924c163b385af7093440184af6fd6244936d1288cbb41cc3812286d3f83a33294fd80900";
    let bytes = hex_to_bytes(hex_string);
    let transaction = Transaction::<365, 2, 1, 83, 2, 1, 65, 1, 207>::new(bytes, true);

    let utxo = hex_to_bytes("983a3400000000002251200f0c8db753acbd17343a39c2f3f4e35e4be6da749f9e35137ab220e7b238a667");

    let leaf_script = hex_to_bytes("c022206d4ddc0e47d2e8f82cbe2fc2d0d749e7bd3338112cecdc76d8f831ae6620dbe0ac");
    let leaf_script_hash = tagged_hash(leaf_script, "TapLeaf".as_bytes());
    
    assert(
        bytes_to_hex(serialize_p2tr_sighash_all_anyonecanpay(
            transaction,
            1,
            1,
            utxo,
            false,
            Option::some(leaf_script_hash),
        ))
            == "d1abdd89b1029835004a48a9fc11c8659e35c93543fda8444ec3b8eb76fe59dd",
    );
}

#[test]
fn test_taproot_sighash_none() {
    let hex_string = "020000000001023cfe8b95d22502698fd98837f83d8d4be31ee3eddd9d1ab1a95654c64604c4d10100000000feffffff3cfe8b95d22502698fd98837f83d8d4be31ee3eddd9d1ab1a95654c64604c4d10000000000ffffffff023acf00000000000017a914453acd285e0b84ce01be507e1de19ebc2494c28d8734a8cc2e0000000017a9146fc16fc2550e819d837d5cc5b37237642ab131978701430141b693a0797b24bae12ed0516a2f5ba765618dca89b75e498ba5b745b71644362298a45ca39230d10a02ee6290a91cebf9839600f7e35158a447ea182ea0e022ae010188034101769105cbcbdcaaee5e58cd201ba3152477fda31410df8b91b4aee2c4864c7700615efb425e002f146a39ca0a4f2924566762d9213bd33f825fad83977fba7f0122206d4ddc0e47d2e8f82cbe2fc2d0d749e7bd3338112cecdc76d8f831ae6620dbe0ac21c0924c163b385af7093440184af6fd6244936d1288cbb41cc3812286d3f83a33294fd80900";
    let bytes = hex_to_bytes(hex_string);
    let transaction = Transaction::<365, 2, 1, 83, 2, 1, 65, 1, 207>::new(bytes, true);

    let utxo_data: [u8; 86] = hex_to_bytes(
        "983a0000000000002251203daaca9b82a51aca960c1491588246029d7e0fc49e0abdbcc8fd17574be5c74b983a3400000000002251200f0c8db753acbd17343a39c2f3f4e35e4be6da749f9e35137ab220e7b238a667",
    );
    let outputs = parse_outputs::<86, 2>(utxo_data);

    assert(
        bytes_to_hex(serialize_p2tr_sighash_none(
            transaction,
            0,
            0,
            outputs,
            utxo_data,
            false,
            Option::none(),
        ))
            == "543fe400cb2a12e7e1903750109a1e558decf7139b99d02377a7a8b41393e986",
    );
}

#[test]
fn test_taproot_sighash_none_with_leaf() {
    let hex_string = "020000000001023cfe8b95d22502698fd98837f83d8d4be31ee3eddd9d1ab1a95654c64604c4d10100000000feffffff3cfe8b95d22502698fd98837f83d8d4be31ee3eddd9d1ab1a95654c64604c4d10000000000ffffffff023acf00000000000017a914453acd285e0b84ce01be507e1de19ebc2494c28d8734a8cc2e0000000017a9146fc16fc2550e819d837d5cc5b37237642ab131978701430141b693a0797b24bae12ed0516a2f5ba765618dca89b75e498ba5b745b71644362298a45ca39230d10a02ee6290a91cebf9839600f7e35158a447ea182ea0e022ae010188034101769105cbcbdcaaee5e58cd201ba3152477fda31410df8b91b4aee2c4864c7700615efb425e002f146a39ca0a4f2924566762d9213bd33f825fad83977fba7f0122206d4ddc0e47d2e8f82cbe2fc2d0d749e7bd3338112cecdc76d8f831ae6620dbe0ac21c0924c163b385af7093440184af6fd6244936d1288cbb41cc3812286d3f83a33294fd80900";
    let bytes = hex_to_bytes(hex_string);
    let transaction = Transaction::<365, 2, 1, 83, 2, 1, 65, 1, 207>::new(bytes, true);

    let utxo_data: [u8; 86] = hex_to_bytes(
        "983a0000000000002251203daaca9b82a51aca960c1491588246029d7e0fc49e0abdbcc8fd17574be5c74b983a3400000000002251200f0c8db753acbd17343a39c2f3f4e35e4be6da749f9e35137ab220e7b238a667",
    );
    let outputs = parse_outputs::<86, 2>(utxo_data);
    let leaf_script = hex_to_bytes("c022206d4ddc0e47d2e8f82cbe2fc2d0d749e7bd3338112cecdc76d8f831ae6620dbe0ac");
    let leaf_script_hash = tagged_hash(leaf_script, "TapLeaf".as_bytes());
    assert(
        bytes_to_hex(serialize_p2tr_sighash_none(
            transaction,
            0,
            1,
            outputs,
            utxo_data,
            false,
            Option::some(leaf_script_hash),
        ))
            == "3450da84da3c201893666bee691ab8fe6494049fa0ff6c6c2ce9169974d7b317",
    );
}

#[test]
fn test_taproot_sighash_none_anyonecanpay() {
    let hex_string = "020000000001023cfe8b95d22502698fd98837f83d8d4be31ee3eddd9d1ab1a95654c64604c4d10100000000feffffff3cfe8b95d22502698fd98837f83d8d4be31ee3eddd9d1ab1a95654c64604c4d10000000000ffffffff023acf00000000000017a914453acd285e0b84ce01be507e1de19ebc2494c28d8734a8cc2e0000000017a9146fc16fc2550e819d837d5cc5b37237642ab131978701430141b693a0797b24bae12ed0516a2f5ba765618dca89b75e498ba5b745b71644362298a45ca39230d10a02ee6290a91cebf9839600f7e35158a447ea182ea0e022ae010188034101769105cbcbdcaaee5e58cd201ba3152477fda31410df8b91b4aee2c4864c7700615efb425e002f146a39ca0a4f2924566762d9213bd33f825fad83977fba7f0122206d4ddc0e47d2e8f82cbe2fc2d0d749e7bd3338112cecdc76d8f831ae6620dbe0ac21c0924c163b385af7093440184af6fd6244936d1288cbb41cc3812286d3f83a33294fd80900";
    let bytes = hex_to_bytes(hex_string);
    let transaction = Transaction::<365, 2, 1, 83, 2, 1, 65, 1, 207>::new(bytes, true);

    let utxo = hex_to_bytes("983a3400000000002251200f0c8db753acbd17343a39c2f3f4e35e4be6da749f9e35137ab220e7b238a667");

    assert(
        bytes_to_hex(serialize_p2tr_sighash_none_anyonecanpay(
            transaction,
            1,
            0,
            utxo,
            false,
            Option::none(),
        ))
            == "5aa697ae3b657a6e484aeddf0392130a76c7da427c833c22df47cd435837677c",
    );
}

#[test]
fn test_taproot_sighash_none_anyonecanpay_with_leaf() {
    let hex_string = "020000000001023cfe8b95d22502698fd98837f83d8d4be31ee3eddd9d1ab1a95654c64604c4d10100000000feffffff3cfe8b95d22502698fd98837f83d8d4be31ee3eddd9d1ab1a95654c64604c4d10000000000ffffffff023acf00000000000017a914453acd285e0b84ce01be507e1de19ebc2494c28d8734a8cc2e0000000017a9146fc16fc2550e819d837d5cc5b37237642ab131978701430141b693a0797b24bae12ed0516a2f5ba765618dca89b75e498ba5b745b71644362298a45ca39230d10a02ee6290a91cebf9839600f7e35158a447ea182ea0e022ae010188034101769105cbcbdcaaee5e58cd201ba3152477fda31410df8b91b4aee2c4864c7700615efb425e002f146a39ca0a4f2924566762d9213bd33f825fad83977fba7f0122206d4ddc0e47d2e8f82cbe2fc2d0d749e7bd3338112cecdc76d8f831ae6620dbe0ac21c0924c163b385af7093440184af6fd6244936d1288cbb41cc3812286d3f83a33294fd80900";
    let bytes = hex_to_bytes(hex_string);
    let transaction = Transaction::<365, 2, 1, 83, 2, 1, 65, 1, 207>::new(bytes, true);

    let utxo = hex_to_bytes("983a3400000000002251200f0c8db753acbd17343a39c2f3f4e35e4be6da749f9e35137ab220e7b238a667");

    let leaf_script = hex_to_bytes("c022206d4ddc0e47d2e8f82cbe2fc2d0d749e7bd3338112cecdc76d8f831ae6620dbe0ac");
    let leaf_script_hash = tagged_hash(leaf_script, "TapLeaf".as_bytes());
    
    assert(
        bytes_to_hex(serialize_p2tr_sighash_none_anyonecanpay(
            transaction,
            1,
            1,
            utxo,
            false,
            Option::some(leaf_script_hash),
        ))
            == "6db68a736f22e21a497418a7987ae6fea734b44edf0ba0b3c64d4c7465d461d8",
    );
}
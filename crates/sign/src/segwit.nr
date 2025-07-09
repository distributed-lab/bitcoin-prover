use crate::legacy::Transaction;
use utils::convert::{bytes_to_hex, hex_to_bytes};

fn prepare_preimage_hash_for_sighash_all<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let SCRIPT_CODE_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    script_code: [u8; SCRIPT_CODE_SIZE],
    prev_amount: [u8; 8],
) -> [u8; 4 + 32 + 32 + (32 + 4) + SCRIPT_CODE_SIZE + 8 + 4 + 32 + 4 + 4] {
    let mut data = [0; 4 + 32 + 32 + (32 + 4) + SCRIPT_CODE_SIZE + 8 + 4 + 32 + 4 + 4];
    let mut cur_pos = 0;

    // Version
    for i in 0..4 {
        data[cur_pos] = transaction.data[i];
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

    let inputs_hash = sha256::digest(sha256::digest(preimage_inputs));
    for i in 0..32 {
        data[cur_pos] = inputs_hash[i];
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

    let sequences_hash = sha256::digest(sha256::digest(preimage_sequences));
    for i in 0..32 {
        data[cur_pos] = sequences_hash[i];
        cur_pos += 1;
    }

    // Input to sign (txid, vout)
    let transaction_input_txid_offset = transaction.inputs[input_to_sign].txid.offset;
    for i in 0..32 {
        data[cur_pos] = transaction.data[transaction_input_txid_offset + i];
        cur_pos += 1;
    }

    let transaction_input_vout_offset = transaction.inputs[input_to_sign].vout.offset;
    for i in 0..4 {
        data[cur_pos] = transaction.data[transaction_input_vout_offset + i];
        cur_pos += 1;
    }

    // Script code
    for i in 0..SCRIPT_CODE_SIZE {
        data[cur_pos] = script_code[i];
        cur_pos += 1;
    }

    // Previous amount
    for i in 0..8 {
        data[cur_pos] = prev_amount[i];
        cur_pos += 1;
    }

    // Sequence
    let transaction_input_sequence_offset = transaction.inputs[input_to_sign].sequence.offset;
    for i in 0..4 {
        data[cur_pos] = transaction.data[transaction_input_sequence_offset + i];
        cur_pos += 1;
    }

    // Outputs
    let mut preimage_outputs = [0; OUTPUT_SIZE - OUTPUT_COUNT_LEN];

    let transaction_output_offset = transaction.output_count.offset + transaction.output_count.size;
    for i in 0..(OUTPUT_SIZE - OUTPUT_COUNT_LEN) {
        preimage_outputs[i] = transaction.data[transaction_output_offset + i];
    }

    let outputs_hash = sha256::digest(sha256::digest(preimage_outputs));
    for i in 0..32 {
        data[cur_pos] = outputs_hash[i];
        cur_pos += 1;
    }

    // Lock time
    let transaction_locktime_offset = transaction.lock_time.offset;
    for i in 0..4 {
        data[cur_pos] = transaction.data[transaction_locktime_offset + i];
        cur_pos += 1;
    }

    // Hash type
    data[cur_pos] = 0x01;
    data[cur_pos + 1] = 0x00;
    data[cur_pos + 2] = 0x00;
    data[cur_pos + 3] = 0x00;
    cur_pos += 4;

    assert(cur_pos == 4 + 32 + 32 + (32 + 4) + SCRIPT_CODE_SIZE + 8 + 4 + 32 + 4 + 4);

    data
}

fn prepare_preimage_hash_for_sighash_all_anyonecanpay<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let SCRIPT_CODE_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    script_code: [u8; SCRIPT_CODE_SIZE],
    prev_amount: [u8; 8],
) -> [u8; 4 + 32 + 32 + (32 + 4) + SCRIPT_CODE_SIZE + 8 + 4 + 32 + 4 + 4] {
    let mut data = [0; 4 + 32 + 32 + (32 + 4) + SCRIPT_CODE_SIZE + 8 + 4 + 32 + 4 + 4];
    let mut cur_pos = 0;

    // Version
    for i in 0..4 {
        data[cur_pos] = transaction.data[i];
        cur_pos += 1;
    }

    // Inputs ((txid, vout) + (txid, vout) + ...) hash 
    for _ in 0..32 {
        data[cur_pos] = 0;
        cur_pos += 1;
    }

    // Sequences (sequence + sequence + ...) hash
    for _ in 0..32 {
        data[cur_pos] = 0;
        cur_pos += 1;
    }

    // Input to sign (txid, vout)
    let transaction_input_txid_offset = transaction.inputs[input_to_sign].txid.offset;
    for i in 0..32 {
        data[cur_pos] = transaction.data[transaction_input_txid_offset + i];
        cur_pos += 1;
    }

    let transaction_input_vout_offset = transaction.inputs[input_to_sign].vout.offset;
    for i in 0..4 {
        data[cur_pos] = transaction.data[transaction_input_vout_offset + i];
        cur_pos += 1;
    }

    // Script code
    for i in 0..SCRIPT_CODE_SIZE {
        data[cur_pos] = script_code[i];
        cur_pos += 1;
    }

    // Previous amount
    for i in 0..8 {
        data[cur_pos] = prev_amount[i];
        cur_pos += 1;
    }

    // Sequence
    let transaction_input_sequence_offset = transaction.inputs[input_to_sign].sequence.offset;
    for i in 0..4 {
        data[cur_pos] = transaction.data[transaction_input_sequence_offset + i];
        cur_pos += 1;
    }

    // Outputs
    let mut preimage_outputs = [0; OUTPUT_SIZE - OUTPUT_COUNT_LEN];

    let transaction_output_offset = transaction.output_count.offset + transaction.output_count.size;
    for i in 0..(OUTPUT_SIZE - OUTPUT_COUNT_LEN) {
        preimage_outputs[i] = transaction.data[transaction_output_offset + i];
    }

    let outputs_hash = sha256::digest(sha256::digest(preimage_outputs));
    for i in 0..32 {
        data[cur_pos] = outputs_hash[i];
        cur_pos += 1;
    }

    // Lock time
    let transaction_locktime_offset = transaction.lock_time.offset;
    for i in 0..4 {
        data[cur_pos] = transaction.data[transaction_locktime_offset + i];
        cur_pos += 1;
    }

    // Hash type
    data[cur_pos] = 0x81;
    data[cur_pos + 1] = 0x00;
    data[cur_pos + 2] = 0x00;
    data[cur_pos + 3] = 0x00;
    cur_pos += 4;

    assert(cur_pos == 4 + 32 + 32 + (32 + 4) + SCRIPT_CODE_SIZE + 8 + 4 + 32 + 4 + 4);

    data
}

// 0x1976a914<public_key_hash>88ac
fn create_p2wpkh_script_code(public_key_hash: [u8; 20]) -> [u8; 26] {
    let mut script_code = [0; 26];
    script_code[0] = 0x19;
    script_code[1] = 0x76;
    script_code[2] = 0xa9;
    script_code[3] = 0x14;
    for i in 0..20 {
        script_code[i + 4] = public_key_hash[i];
    }
    script_code[24] = 0x88;
    script_code[25] = 0xac;

    script_code
}

pub fn serialize_p2wpkh_sighash_all<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    prev_amount: [u8; 8],
    script_code: [u8; 26],
) -> [u8; 32] {
    let preimage_data =
        prepare_preimage_hash_for_sighash_all(transaction, input_to_sign, script_code, prev_amount);

    let sighash_all = sha256::digest(sha256::digest(preimage_data));

    sighash_all
}

pub fn serialize_p2wpkh_sighash_all_anyonecanpay<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    prev_amount: [u8; 8],
    script_code: [u8; 26],
) -> [u8; 32] {
    let preimage_data =
        prepare_preimage_hash_for_sighash_all_anyonecanpay(transaction, input_to_sign, script_code, prev_amount);

    let sighash_all = sha256::digest(sha256::digest(preimage_data));

    sighash_all
}

#[test]
fn test_serialize_p2wpkh_sighash_all() {
    let hex_string = "02000000000101ac4994014aa36b7f53375658ef595b3cb2891e1735fe5b441686f5e53338e76a0100000000ffffffff01204e0000000000001976a914ce72abfd0e6d9354a660c18f2825eb392f060fdc88ac0000000000";
    let bytes = hex_to_bytes(hex_string);
    let transaction = Transaction::<88, 1, 1, 42, 1, 1, 35, 1, 1>::new(bytes, true);

    let script_pub_key = "1976a914aa966f56de599b4094b61aa68a2b3df9e97e9c4888ac";
    let script_pub_key_bytes = hex_to_bytes(script_pub_key);

    let prev_amount_hex = "3075000000000000";
    let prev_amount_bytes = hex_to_bytes(prev_amount_hex);

    let sighash_all_transaction_bytes =
        serialize_p2wpkh_sighash_all(transaction, 0, prev_amount_bytes, script_pub_key_bytes);

    let sighash_all_transaction = bytes_to_hex(sighash_all_transaction_bytes);

    assert(
        sighash_all_transaction
            == "d7b60220e1b9b2c1ab40845118baf515203f7b6f0ad83cbb68d3c89b5b3098a6",
    );
}

#[test] 
fn test_serialize_p2wpkh_sighash_all_anyonecanpay() { 
    let hex_string = "02000000000101ac4994014aa36b7f53375658ef595b3cb2891e1735fe5b441686f5e53338e76a0100000000ffffffff01204e0000000000001976a914ce72abfd0e6d9354a660c18f2825eb392f060fdc88ac0000000000"; 
    let bytes = hex_to_bytes(hex_string); 
    let transaction = Transaction::<88, 1, 1, 42, 1, 1, 35, 1, 1>::new(bytes, true); 
 
    let script_pub_key = "1976a914aa966f56de599b4094b61aa68a2b3df9e97e9c4888ac"; 
    let script_pub_key_bytes = hex_to_bytes(script_pub_key); 
 
    let prev_amount_hex = "3075000000000000"; 
    let prev_amount_bytes = hex_to_bytes(prev_amount_hex); 
 
    let sighash_all_transaction_bytes = 
        serialize_p2wpkh_sighash_all_anyonecanpay(transaction, 0, prev_amount_bytes, script_pub_key_bytes); 
 
    let sighash_all_transaction = bytes_to_hex(sighash_all_transaction_bytes); 
     
    println(sighash_all_transaction); 
 
    assert( 
        sighash_all_transaction 
            == "d74d6caf8ee5103748ee3c5abc645decf5b893a494fdd38dc161d9bd306c357b", 
    ); 
}

mod globals;

use bvm::stack::{empty_stack_array, Stack};
use crypto::{merkle::calc_merkle_root, point::check_tweaked_pub_key, schnorr::tagged_hash};
use globals::{
    CONTROL_BLOCK_LEN, CUR_IS_GEGWIT, CUR_TX_INP_COUNT, CUR_TX_INP_COUNT_LEN, CUR_TX_INP_SIZE,
    CUR_TX_LEN, CUR_TX_MAX_WITNESS_STACK_SIZE, CUR_TX_OUT_COUNT, CUR_TX_OUT_COUNT_LEN,
    CUR_TX_OUT_SIZE, CUR_TX_WITNESS_SIZE, INPUT_WITNESS_LEN, MAX_STACK_ELEMENT_SIZE, N_OUTPUT_SIZE,
    PREV_IS_GEGWIT, PREV_TX_INP_COUNT, PREV_TX_INP_COUNT_LEN, PREV_TX_INP_SIZE, PREV_TX_LEN,
    PREV_TX_MAX_WITNESS_STACK_SIZE, PREV_TX_OUT_COUNT, PREV_TX_OUT_COUNT_LEN, PREV_TX_OUT_SIZE,
    PREV_TX_WITNESS_SIZE, SCRIPT_LEN, SCRIPT_LEN_LEN, SCRIPT_OPCODES_AMOUNT, STACK_SIZE, UTXOS_LEN,
};
use script::execution::ScriptExecutionEngine;
use sign::{address::Address, compact_size::u32_to_compact_size_array, transaction::Transaction};
use utils::convert::{bytes_to_hex, hex_to_bytes, le_bytes_to_u32};

// Script path spend
fn main(
    cur_tx_data: str<CUR_TX_LEN>,
    prev_tx_data: str<PREV_TX_LEN>,
    utxos_data: [u8; UTXOS_LEN],
    input_to_sign: pub u32,
) -> pub bool {
    assert(CONTROL_BLOCK_LEN % 32 == 1);

    let cur_tx_data = hex_to_bytes(cur_tx_data);
    let prev_tx_data = hex_to_bytes(prev_tx_data);

    let cur_tx = Transaction::<CUR_TX_LEN / 2, CUR_TX_INP_COUNT, CUR_TX_INP_COUNT_LEN, CUR_TX_INP_SIZE, CUR_TX_OUT_COUNT, CUR_TX_OUT_COUNT_LEN, CUR_TX_OUT_SIZE, CUR_TX_MAX_WITNESS_STACK_SIZE, CUR_TX_WITNESS_SIZE>::new(
        cur_tx_data,
        CUR_IS_GEGWIT,
    );

    let prev_tx = Transaction::<PREV_TX_LEN / 2, PREV_TX_INP_COUNT, PREV_TX_INP_COUNT_LEN, PREV_TX_INP_SIZE, PREV_TX_OUT_COUNT, PREV_TX_OUT_COUNT_LEN, PREV_TX_OUT_SIZE, PREV_TX_MAX_WITNESS_STACK_SIZE, PREV_TX_WITNESS_SIZE>::new(
        prev_tx_data,
        PREV_IS_GEGWIT,
    );

    let vout_pos = cur_tx.inputs[input_to_sign].vout.offset;
    let mut vout_bytes = [0; 4];
    for i in 0..4 {
        vout_bytes[i] = cur_tx.data[vout_pos + i];
    }

    let vout = le_bytes_to_u32(vout_bytes);
    let script_pub_key_offset = prev_tx.outputs[vout].script_pub_key.offset;

    let mut tweaked_pub_key = [0; 32];

    for i in 0..32 {
        tweaked_pub_key[i] = prev_tx.data[script_pub_key_offset + i + 2];
    }

    let witness = cur_tx.witness.unwrap()[input_to_sign].items;

    let mut script = [0; SCRIPT_LEN];
    let script_offset = witness.get(witness.len() - 2).unwrap().item.offset;

    for i in 0..SCRIPT_LEN {
        script[i] = cur_tx.data[script_offset + i];
    }

    let mut control_block = [0; CONTROL_BLOCK_LEN];
    let control_block_offset = witness.get(witness.len() - 1).unwrap().item.offset;

    for i in 0..CONTROL_BLOCK_LEN {
        control_block[i] = cur_tx.data[control_block_offset + i];
    }

    let is_even = (control_block[0] & 1) == 0;
    let script_version = control_block[0] - (!is_even) as u8;

    let mut pub_key_x = [0; 32];
    for i in 0..32 {
        pub_key_x[i] = control_block[i + 1];
    }

    // First hash in merkle path will be our script hash
    let mut merkle_path = [[0; 32]; (CONTROL_BLOCK_LEN - 1) / 32];

    merkle_path[0] = tagged_hash(
        u32_to_compact_size_array::<SCRIPT_LEN_LEN>(SCRIPT_LEN)
            .as_slice()
            .append(script)
            .push_front(script_version)
            .as_array::<1 + SCRIPT_LEN + SCRIPT_LEN_LEN>(),
        "TapLeaf".as_bytes(),
    );

    for i in 0..((CONTROL_BLOCK_LEN - 1) / 32 - 1) {
        for j in 0..32 {
            merkle_path[i + 1][j] = control_block[i * 32 + j + 33];
        }
    }

    let merkle_root = calc_merkle_root(merkle_path);

    assert(check_tweaked_pub_key(pub_key_x, is_even, merkle_root, tweaked_pub_key));

    let mut stack = Stack::new(
        cur_tx,
        prev_tx,
        input_to_sign,
        vout,
        empty_stack_array::<MAX_STACK_ELEMENT_SIZE, STACK_SIZE>(),
        [],
    );

    let mut script_execution_engine = ScriptExecutionEngine::new(stack);

    let mut witness = [0; INPUT_WITNESS_LEN];
    let witness_input_offset =
        cur_tx.witness.unwrap()[input_to_sign].items.get(0).unwrap().size.offset;
    for i in 0..INPUT_WITNESS_LEN {
        witness[i] = cur_tx.data[witness_input_offset + i];
    }
    script_execution_engine.add_witness_to_stack(witness);

    script_execution_engine
        .execute::<SCRIPT_LEN, N_OUTPUT_SIZE, 0, 0, 0, SCRIPT_OPCODES_AMOUNT, 0, UTXOS_LEN>(
            script,
            Address::new_p2tr(),
            utxos_data,
            Option::some(merkle_path[0]),
        );

    script_execution_engine.stack.op_verify()
}

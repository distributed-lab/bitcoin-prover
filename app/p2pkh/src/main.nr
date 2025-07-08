mod globals;

use bvm::stack::{empty_stack_array, Stack};
use globals::{
    CUR_TX_INP_COUNT, CUR_TX_INP_COUNT_LEN, CUR_TX_INP_SIZE, CUR_TX_LEN,
    CUR_TX_MAX_WITNESS_STACK_SIZE, CUR_TX_OUT_COUNT, CUR_TX_OUT_COUNT_LEN, CUR_TX_OUT_SIZE,
    CUR_TX_WITNESS_SIZE, OPCODES_AMOUNT, PK_LEN, PREV_TX_INP_COUNT, PREV_TX_INP_COUNT_LEN,
    PREV_TX_INP_SIZE, PREV_TX_LEN, PREV_TX_MAX_WITNESS_STACK_SIZE, PREV_TX_OUT_COUNT,
    PREV_TX_OUT_COUNT_LEN, PREV_TX_OUT_SIZE, PREV_TX_WITNESS_SIZE, SIG_LEN,
};
use script::execution::ScriptExecutionEngine;
use sign::{address::Address, transaction::Transaction};
use utils::convert::{hex_to_bytes, le_bytes_to_u32};

fn main(
    cur_tx_data: str<CUR_TX_LEN>,
    prev_tx_data: str<PREV_TX_LEN>,
    signature: str<SIG_LEN>,
    pub_key: str<PK_LEN>,
    input_to_sign: pub u32,
) -> pub bool {
    let cur_tx_data = hex_to_bytes(cur_tx_data);
    let prev_tx_data = hex_to_bytes(prev_tx_data);

    let cur_tx = Transaction::<CUR_TX_LEN / 2, CUR_TX_INP_COUNT, CUR_TX_INP_COUNT_LEN, CUR_TX_INP_SIZE, CUR_TX_OUT_COUNT, CUR_TX_OUT_COUNT_LEN, CUR_TX_OUT_SIZE, CUR_TX_MAX_WITNESS_STACK_SIZE, CUR_TX_WITNESS_SIZE>::new(
        cur_tx_data,
        false,
    );

    let prev_tx = Transaction::<PREV_TX_LEN / 2, PREV_TX_INP_COUNT, PREV_TX_INP_COUNT_LEN, PREV_TX_INP_SIZE, PREV_TX_OUT_COUNT, PREV_TX_OUT_COUNT_LEN, PREV_TX_OUT_SIZE, PREV_TX_MAX_WITNESS_STACK_SIZE, PREV_TX_WITNESS_SIZE>::new(
        prev_tx_data,
        false,
    );

    let mut script_pub_key = [0; 25];

    let vout_pos = cur_tx.inputs[input_to_sign].vout.offset;
    let mut vout_bytes = [0; 4];
    for i in 0..4 {
        vout_bytes[i] = cur_tx.data[vout_pos + i];
    }

    let vout = le_bytes_to_u32(vout_bytes);
    let script_pub_key_pos = prev_tx.outputs[vout].script_pub_key.offset;
    for i in 0..25 {
        script_pub_key[i] = prev_tx.data[script_pub_key_pos + i];
    }

    let mut stack = Stack::new(
        cur_tx,
        prev_tx,
        input_to_sign,
        vout,
        empty_stack_array::<80, 7>(),
    );

    let mut script_execution_engine = ScriptExecutionEngine::new(stack);

    let signature_bytes = hex_to_bytes(signature);
    let pub_key_bytes = hex_to_bytes(pub_key);

    let script = [signature_bytes.len() as u8]
        .as_slice()
        .append(signature_bytes.as_slice())
        .push_back(pub_key_bytes.len() as u8)
        .append(pub_key_bytes.as_slice())
        .append(script_pub_key.as_slice())
        .as_array::<SIG_LEN / 2 + PK_LEN / 2 + 25 + 2>();

    // 0c83d25a8fce5065fc8d4b398a91d203eb49eebe
    // 0900bb14c7cb6a52fd8a22fd68a5986eb193c9f5
    script_execution_engine
        .execute::<SIG_LEN / 2 + PK_LEN / 2 + 25 + 2, OPCODES_AMOUNT, 20, 33, 65, 70, 71, 72, 26, 0, 0, 0, 0>(
            script,
            Address::new_p2pkh(),
        );

    script_execution_engine.stack.op_verify()
}

mod globals;

use bvm::stack::{empty_stack_array, Stack};
use globals::{
    CUR_TX_INP_COUNT, CUR_TX_INP_COUNT_LEN, CUR_TX_INP_SIZE, CUR_TX_LEN, CUR_TX_OUT_COUNT,
    CUR_TX_OUT_COUNT_LEN, CUR_TX_OUT_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN, N_INPUT_SIZE,
    N_OUTPUT_SIZE, PREV_IS_GEGWIT, PREV_TX_INP_COUNT, PREV_TX_INP_COUNT_LEN, PREV_TX_INP_SIZE,
    PREV_TX_LEN, PREV_TX_MAX_WITNESS_STACK_SIZE, PREV_TX_OUT_COUNT, PREV_TX_OUT_COUNT_LEN,
    PREV_TX_OUT_SIZE, PREV_TX_WITNESS_SIZE, SCRIPT_PUB_KEY_LEN, SCRIPT_SIG_LEN,
};
use script::execution::ScriptExecutionEngine;
use sign::{address::Address, transaction::Transaction};
use utils::convert::{byte_to_hex_symbol, bytes_to_hex, hex_to_bytes, le_bytes_to_u32};

fn main(
    cur_tx_data: str<CUR_TX_LEN>,
    prev_tx_data: str<PREV_TX_LEN>,
    script_sig: str<SCRIPT_SIG_LEN>,
    input_to_sign: pub u32,
) -> pub bool {
    let cur_tx_data = hex_to_bytes(cur_tx_data);
    let prev_tx_data = hex_to_bytes(prev_tx_data);

    let cur_tx = Transaction::<CUR_TX_LEN / 2, CUR_TX_INP_COUNT, CUR_TX_INP_COUNT_LEN, CUR_TX_INP_SIZE, CUR_TX_OUT_COUNT, CUR_TX_OUT_COUNT_LEN, CUR_TX_OUT_SIZE, 0, 0>::new(
        cur_tx_data,
        false,
    );

    let prev_tx = Transaction::<PREV_TX_LEN / 2, PREV_TX_INP_COUNT, PREV_TX_INP_COUNT_LEN, PREV_TX_INP_SIZE, PREV_TX_OUT_COUNT, PREV_TX_OUT_COUNT_LEN, PREV_TX_OUT_SIZE, PREV_TX_MAX_WITNESS_STACK_SIZE, PREV_TX_WITNESS_SIZE>::new(
        prev_tx_data,
        PREV_IS_GEGWIT,
    );

    let mut script_pub_key = [0; SCRIPT_PUB_KEY_LEN];

    let vout_pos = cur_tx.inputs[input_to_sign].vout.offset;
    let mut vout_bytes = [0; 4];
    for i in 0..4 {
        vout_bytes[i] = cur_tx.data[vout_pos + i];
    }

    let vout = le_bytes_to_u32(vout_bytes);
    let script_pub_key_pos = prev_tx.outputs[vout].script_pub_key.offset;

    let script_sig_bytes = hex_to_bytes(script_sig);

    for i in 0..SCRIPT_PUB_KEY_LEN {
        script_pub_key[i] = prev_tx.data[script_pub_key_pos + i];
    }

    let mut stack = Stack::new(
        cur_tx,
        prev_tx,
        input_to_sign,
        vout,
        empty_stack_array::<80, 3>(),
        [],
    );

    let mut script_execution_engine = ScriptExecutionEngine::new(stack);

    let script = script_sig_bytes
        .as_slice()
        .append(script_pub_key.as_slice())
        .as_array::<SCRIPT_SIG_LEN / 2 + SCRIPT_PUB_KEY_LEN>();

    script_execution_engine
        .execute::<SCRIPT_SIG_LEN / 2 + SCRIPT_PUB_KEY_LEN, N_OUTPUT_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN, N_INPUT_SIZE, 3, SCRIPT_PUB_KEY_LEN + 1, 0>(
            script,
            Address::new_p2pk(),
            [],
            Option::none(),
        );

    script_execution_engine.stack.op_verify()
}

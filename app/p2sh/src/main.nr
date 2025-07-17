mod globals;

use bvm::stack::{empty_stack_array, Stack};
use globals::{
    CUR_IS_GEGWIT, CUR_TX_INP_COUNT, CUR_TX_INP_COUNT_LEN, CUR_TX_INP_SIZE, CUR_TX_LEN,
    CUR_TX_MAX_WITNESS_STACK_SIZE, CUR_TX_OUT_COUNT, CUR_TX_OUT_COUNT_LEN, CUR_TX_OUT_SIZE,
    CUR_TX_WITNESS_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN, MAX_STACK_ELEMENT_SIZE, N_INPUT_SIZE,
    N_OUTPUT_SIZE, OPCODES_AMOUNT, PREV_IS_GEGWIT, PREV_TX_INP_COUNT, PREV_TX_INP_COUNT_LEN,
    PREV_TX_INP_SIZE, PREV_TX_LEN, PREV_TX_MAX_WITNESS_STACK_SIZE, PREV_TX_OUT_COUNT,
    PREV_TX_OUT_COUNT_LEN, PREV_TX_OUT_SIZE, PREV_TX_WITNESS_SIZE, REDEEM_SCRIPT_LEN,
    REDEEM_SCRIPT_OPCODES_AMOUNT, SCRIPT_PUB_KEY_LEN, SCRIPT_PUB_KEY_LEN_LEN, SCRIPT_SIG_LEN,
    STACK_SIZE,
};
use script::execution::ScriptExecutionEngine;
use sign::{address::Address, transaction::Transaction};
use utils::convert::{hex_to_bytes, le_bytes_to_u32};

fn main(
    cur_tx_data: str<CUR_TX_LEN>,
    prev_tx_data: str<PREV_TX_LEN>,
    script_sig: str<SCRIPT_SIG_LEN>,
    input_to_sign: pub u32,
) -> pub bool {
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

    let mut script_pub_key = [0; SCRIPT_PUB_KEY_LEN];

    let vout_pos = cur_tx.inputs[input_to_sign].vout.offset;
    let mut vout_bytes = [0; 4];
    for i in 0..4 {
        vout_bytes[i] = cur_tx.data[vout_pos + i];
    }

    let vout = le_bytes_to_u32(vout_bytes);
    let script_pub_key_pos = prev_tx.outputs[vout].script_pub_key.offset;
    assert(prev_tx.data[script_pub_key_pos] == 0);

    if CUR_IS_GEGWIT {
        assert(SCRIPT_PUB_KEY_LEN == 35);
        script_pub_key[0] = 169;
        script_pub_key[1] = 32;
        for i in 2..34 {
            script_pub_key[i] = prev_tx.data[script_pub_key_pos + i - 1];
        }
        script_pub_key[34] = 135;
    } else {
        assert(SCRIPT_PUB_KEY_LEN == 23);
        for i in 0..SCRIPT_PUB_KEY_LEN {
            script_pub_key[i] = prev_tx.data[script_pub_key_pos + i];
        }
    }

    let mut stack = Stack::new(
        cur_tx,
        prev_tx,
        input_to_sign,
        vout,
        empty_stack_array::<MAX_STACK_ELEMENT_SIZE, STACK_SIZE>(),
    );

    let mut script_execution_engine = ScriptExecutionEngine::new(stack);

    let script_sig_bytes = hex_to_bytes(script_sig);

    let mut redeem_script = [0; REDEEM_SCRIPT_LEN];

    for i in 0..REDEEM_SCRIPT_LEN {
        redeem_script[REDEEM_SCRIPT_LEN - 1 - i] = script_sig_bytes[(SCRIPT_SIG_LEN / 2) - 1 - i];
    }

    let script = script_sig_bytes
        .as_slice()
        .append(script_pub_key.as_slice())
        .as_array::<SCRIPT_SIG_LEN / 2 + SCRIPT_PUB_KEY_LEN>();

    let address = Address::new_p2sh();

    script_execution_engine
        .execute::<SCRIPT_SIG_LEN / 2 + SCRIPT_PUB_KEY_LEN, N_OUTPUT_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN, N_INPUT_SIZE, OPCODES_AMOUNT, SCRIPT_PUB_KEY_LEN>(
            script,
            address,
        );

    assert(script_execution_engine.stack.op_verify());

    script_execution_engine
        .execute::<REDEEM_SCRIPT_LEN, N_OUTPUT_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN, N_INPUT_SIZE, REDEEM_SCRIPT_OPCODES_AMOUNT, REDEEM_SCRIPT_LEN>(
            redeem_script,
            address,
        );

    script_execution_engine.stack.op_verify()
}

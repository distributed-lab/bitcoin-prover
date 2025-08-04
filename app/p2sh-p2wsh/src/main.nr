mod globals;

use bvm::stack::{empty_stack_array, Stack};
use globals::{
    CODESEPARATOR_REDEEM_SCRIPT_LEN, CODESEPARATOR_REDEEM_SCRIPT_LEN_LEN, CUR_TX_INP_COUNT,
    CUR_TX_INP_COUNT_LEN, CUR_TX_INP_SIZE, CUR_TX_LEN, CUR_TX_MAX_WITNESS_STACK_SIZE,
    CUR_TX_OUT_COUNT, CUR_TX_OUT_COUNT_LEN, CUR_TX_OUT_SIZE, CUR_TX_WITNESS_SIZE, INPUT_TO_SIGN,
    INPUT_TO_SIGN_LEN, MAX_STACK_ELEMENT_SIZE, N_INPUT_SIZE, N_OUTPUT_SIZE, OPCODES_AMOUNT,
    PREV_IS_GEGWIT, PREV_TX_INP_COUNT, PREV_TX_INP_COUNT_LEN, PREV_TX_INP_SIZE, PREV_TX_LEN,
    PREV_TX_MAX_WITNESS_STACK_SIZE, PREV_TX_OUT_COUNT, PREV_TX_OUT_COUNT_LEN, PREV_TX_OUT_SIZE,
    PREV_TX_WITNESS_SIZE, REDEEM_SCRIPT_LEN, REDEEM_SCRIPT_OPCODES_AMOUNT, SCRIPT_PUB_KEY_LEN,
    SCRIPT_SIG_LEN, STACK_SIZE, WITNESS_SCRIPT_LEN,
};
use script::execution::ScriptExecutionEngine;
use sign::{address::Address, compact_size::u32_to_compact_size_array, transaction::Transaction};
use utils::convert::{hex_to_bytes, le_bytes_to_u32};

fn main(
    cur_tx_data: str<CUR_TX_LEN>,
    prev_tx_data: str<PREV_TX_LEN>,
    script_sig: str<SCRIPT_SIG_LEN>,
    witness_script: str<WITNESS_SCRIPT_LEN>,
    input_to_sign: pub u32,
) -> pub bool {
    let cur_tx_data = hex_to_bytes(cur_tx_data);
    let prev_tx_data = hex_to_bytes(prev_tx_data);

    let cur_tx = Transaction::<CUR_TX_LEN / 2, CUR_TX_INP_COUNT, CUR_TX_INP_COUNT_LEN, CUR_TX_INP_SIZE, CUR_TX_OUT_COUNT, CUR_TX_OUT_COUNT_LEN, CUR_TX_OUT_SIZE, CUR_TX_MAX_WITNESS_STACK_SIZE, CUR_TX_WITNESS_SIZE>::new(
        cur_tx_data,
        true,
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

    assert(SCRIPT_PUB_KEY_LEN == 23);
    for i in 0..SCRIPT_PUB_KEY_LEN {
        script_pub_key[i] = prev_tx.data[script_pub_key_pos + i];
    }

    let script_sig_bytes = hex_to_bytes(script_sig);

    let mut sig_script = [0; 35];

    sig_script[0] = 0xa8;
    sig_script[1] = 0x20;
    for i in 2..34 {
        sig_script[i] = script_sig_bytes[i + 1];
    }
    sig_script[34] = 0x87;

    let mut redeem_script = [0; REDEEM_SCRIPT_LEN];
    let mut codeseparator_redeem_script = [0; CODESEPARATOR_REDEEM_SCRIPT_LEN];
    let witness_script = hex_to_bytes(witness_script);

    for i in 0..REDEEM_SCRIPT_LEN {
        redeem_script[REDEEM_SCRIPT_LEN - 1 - i] = witness_script[(WITNESS_SCRIPT_LEN / 2) - 1 - i];
    }

    for i in 0..CODESEPARATOR_REDEEM_SCRIPT_LEN {
        codeseparator_redeem_script[CODESEPARATOR_REDEEM_SCRIPT_LEN - 1 - i] =
            witness_script[(WITNESS_SCRIPT_LEN / 2) - 1 - i];
    }

    let mut stack = Stack::new(
        cur_tx,
        prev_tx,
        input_to_sign,
        vout,
        empty_stack_array::<MAX_STACK_ELEMENT_SIZE, STACK_SIZE>(),
        u32_to_compact_size_array::<CODESEPARATOR_REDEEM_SCRIPT_LEN_LEN>(
            CODESEPARATOR_REDEEM_SCRIPT_LEN,
        )
            .as_slice()
            .append(codeseparator_redeem_script)
            .as_array::<CODESEPARATOR_REDEEM_SCRIPT_LEN_LEN + CODESEPARATOR_REDEEM_SCRIPT_LEN>(),
    );

    let mut script_execution_engine = ScriptExecutionEngine::new(stack);

    let script = script_sig_bytes
        .as_slice()
        .append(script_pub_key.as_slice())
        .as_array::<SCRIPT_SIG_LEN / 2 + SCRIPT_PUB_KEY_LEN>();

    script_execution_engine
        .execute::<SCRIPT_SIG_LEN / 2 + SCRIPT_PUB_KEY_LEN, N_OUTPUT_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN, N_INPUT_SIZE, 4, 0, 0>(
            script,
            Address::new_p2sh(),
            [],
            Option::none(),
        );

    assert(script_execution_engine.stack.op_verify());

    let script = witness_script
        .as_slice()
        .append(sig_script.as_slice())
        .as_array::<WITNESS_SCRIPT_LEN / 2 + 35>();

    script_execution_engine
        .execute::<WITNESS_SCRIPT_LEN / 2 + 35, N_OUTPUT_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN, N_INPUT_SIZE, OPCODES_AMOUNT, 0, 0>(
            script,
            Address::new_p2wsh(),
            [],
            Option::none(),
        );

    assert(script_execution_engine.stack.op_verify());

    script_execution_engine
        .execute::<REDEEM_SCRIPT_LEN, N_OUTPUT_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN, N_INPUT_SIZE, REDEEM_SCRIPT_OPCODES_AMOUNT, 0, 0>(
            redeem_script,
            Address::new_p2wsh(),
            [],
            Option::none(),
        );

    script_execution_engine.stack.op_verify()
}

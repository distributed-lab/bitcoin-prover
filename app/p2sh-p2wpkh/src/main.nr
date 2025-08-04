mod globals;

use bvm::stack::{empty_stack_array, Stack};
use globals::{
    CUR_TX_INP_COUNT, CUR_TX_INP_COUNT_LEN, CUR_TX_INP_SIZE, CUR_TX_LEN,
    CUR_TX_MAX_WITNESS_STACK_SIZE, CUR_TX_OUT_COUNT, CUR_TX_OUT_COUNT_LEN, CUR_TX_OUT_SIZE,
    CUR_TX_WITNESS_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN, MAX_STACK_ELEMENT_SIZE, N_INPUT_SIZE,
    N_OUTPUT_SIZE, PK_LEN, PREV_IS_GEGWIT, PREV_TX_INP_COUNT, PREV_TX_INP_COUNT_LEN,
    PREV_TX_INP_SIZE, PREV_TX_LEN, PREV_TX_MAX_WITNESS_STACK_SIZE, PREV_TX_OUT_COUNT,
    PREV_TX_OUT_COUNT_LEN, PREV_TX_OUT_SIZE, PREV_TX_WITNESS_SIZE, REDEEM_SCRIPT_LEN,
    SCRIPT_PUB_KEY_LEN, SCRIPT_SIG_LEN, SIG_LEN, STACK_SIZE,
};
use script::execution::ScriptExecutionEngine;
use sign::{address::Address, compact_size::u32_to_compact_size_array, transaction::Transaction};
use utils::convert::{hex_to_bytes, le_bytes_to_u32};

fn main(
    cur_tx_data: str<CUR_TX_LEN>,
    prev_tx_data: str<PREV_TX_LEN>,
    script_sig: str<SCRIPT_SIG_LEN>,
    signature: str<SIG_LEN>,
    pub_key: str<PK_LEN>,
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

    // REDEEM_SCRIPT_LEN - p2pkh (not p2wpkh) len
    assert(REDEEM_SCRIPT_LEN == 26);
    let mut redeem_script = [0; REDEEM_SCRIPT_LEN];

    redeem_script[0] = 0x19;
    redeem_script[1] = 0x76;
    redeem_script[2] = 0xa9;
    redeem_script[3] = 0x14;
    for i in 4..(REDEEM_SCRIPT_LEN - 2) {
        redeem_script[i] = script_sig_bytes[i - 1];
    }
    redeem_script[REDEEM_SCRIPT_LEN - 2] = 0x88;
    redeem_script[REDEEM_SCRIPT_LEN - 1] = 0xac;

    let mut stack = Stack::new(
        cur_tx,
        prev_tx,
        input_to_sign,
        vout,
        empty_stack_array::<MAX_STACK_ELEMENT_SIZE, STACK_SIZE>(),
        redeem_script,
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

    let signature_bytes = hex_to_bytes(signature);
    let pub_key_bytes = hex_to_bytes(pub_key);
    let script = [signature_bytes.len() as u8]
        .as_slice()
        .append(signature_bytes.as_slice())
        .push_back(pub_key_bytes.len() as u8)
        .append(pub_key_bytes.as_slice())
        .append(redeem_script.as_slice().pop_front().1)
        .as_array::<SIG_LEN / 2 + PK_LEN / 2 + 25 + 2>();

    script_execution_engine
        .execute::<SIG_LEN / 2 + PK_LEN / 2 + 25 + 2, N_OUTPUT_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN, N_INPUT_SIZE, 7, 0, 0>(
            script,
            Address::new_p2wpkh(),
            [],
            Option::none(),
        );

    script_execution_engine.stack.op_verify()
}

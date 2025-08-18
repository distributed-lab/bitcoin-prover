mod globals;

use bvm::stack::{empty_stack_array, Stack};
use globals::{
    CUR_IS_GEGWIT, CUR_TX_INP_COUNT, CUR_TX_INP_COUNT_LEN, CUR_TX_INP_SIZE, CUR_TX_LEN,
    CUR_TX_MAX_WITNESS_STACK_SIZE, CUR_TX_OUT_COUNT, CUR_TX_OUT_COUNT_LEN, CUR_TX_OUT_SIZE,
    CUR_TX_WITNESS_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN, N_INPUT_SIZE, N_OUTPUT_SIZE,
    OPCODES_AMOUNT, PK_LEN, PREV_IS_GEGWIT, PREV_TX_INP_COUNT, PREV_TX_INP_COUNT_LEN,
    PREV_TX_INP_SIZE, PREV_TX_LEN, PREV_TX_MAX_WITNESS_STACK_SIZE, PREV_TX_OUT_COUNT,
    PREV_TX_OUT_COUNT_LEN, PREV_TX_OUT_SIZE, PREV_TX_WITNESS_SIZE, SCRIPT_SIG_LEN, SIG_LEN,
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

    let cur_tx = Transaction::<CUR_TX_LEN / 2, CUR_TX_INP_COUNT, CUR_TX_INP_COUNT_LEN, CUR_TX_INP_SIZE, CUR_TX_OUT_COUNT, CUR_TX_OUT_COUNT_LEN, CUR_TX_OUT_SIZE, CUR_TX_MAX_WITNESS_STACK_SIZE, CUR_TX_WITNESS_SIZE>::new(
        cur_tx_data,
        CUR_IS_GEGWIT,
    );

    let prev_tx = Transaction::<PREV_TX_LEN / 2, PREV_TX_INP_COUNT, PREV_TX_INP_COUNT_LEN, PREV_TX_INP_SIZE, PREV_TX_OUT_COUNT, PREV_TX_OUT_COUNT_LEN, PREV_TX_OUT_SIZE, PREV_TX_MAX_WITNESS_STACK_SIZE, PREV_TX_WITNESS_SIZE>::new(
        prev_tx_data,
        PREV_IS_GEGWIT,
    );

    let mut script_pub_key = [0; 25];

    let vout_pos = cur_tx.inputs[input_to_sign].vout.offset;
    let mut vout_bytes = [0; 4];
    for i in 0..4 {
        vout_bytes[i] = cur_tx.data[vout_pos + i];
    }

    let vout = le_bytes_to_u32(vout_bytes);
    let script_pub_key_pos = prev_tx.outputs[vout].script_pub_key.offset;

    let mut signature_bytes = [0; SIG_LEN / 2];
    let mut pub_key_bytes = [0; PK_LEN / 2];
    let script_sig_bytes = hex_to_bytes(script_sig);

    if CUR_IS_GEGWIT {
        let witness = cur_tx.witness.unwrap()[input_to_sign];
        let sig_item = witness.items.get(0).unwrap().item;
        assert(sig_item.size == (SIG_LEN / 2));
        let signature_bytes_offset = sig_item.offset;

        for i in 0..(SIG_LEN / 2) {
            signature_bytes[i] = cur_tx.data[signature_bytes_offset + i];
        }

        let pk_item = witness.items.get(1).unwrap().item;
        assert(pk_item.size == (PK_LEN / 2));
        let pk_bytes_offset = pk_item.offset;

        for i in 0..(PK_LEN / 2) {
            pub_key_bytes[i] = cur_tx.data[pk_bytes_offset + i];
        }

        assert(prev_tx.data[script_pub_key_pos] == 0);
        script_pub_key[0] = 118;
        script_pub_key[1] = 169;
        script_pub_key[2] = 20;
        for i in 3..23 {
            script_pub_key[i] = prev_tx.data[script_pub_key_pos + i - 1];
        }
        script_pub_key[23] = 136;
        script_pub_key[24] = 172;
    } else {
        for i in 0..(SIG_LEN / 2) {
            signature_bytes[i] = script_sig_bytes[i + 1];
        }
        for i in 0..(PK_LEN / 2) {
            pub_key_bytes[i] = script_sig_bytes[(SIG_LEN / 2) + i + 2];
        }
        for i in 0..25 {
            script_pub_key[i] = prev_tx.data[script_pub_key_pos + i];
        }
    }

    let mut stack = Stack::new(
        cur_tx,
        prev_tx,
        input_to_sign,
        vout,
        empty_stack_array::<80, 7>(),
        [],
    );

    let mut script_execution_engine = ScriptExecutionEngine::new(stack);

    let script = [signature_bytes.len() as u8]
        .as_slice()
        .append(signature_bytes.as_slice())
        .push_back(pub_key_bytes.len() as u8)
        .append(pub_key_bytes.as_slice())
        .append(script_pub_key.as_slice())
        .as_array::<SIG_LEN / 2 + PK_LEN / 2 + 25 + 2>();

    let address = if CUR_IS_GEGWIT {
        Address::new_p2wpkh()
    } else {
        Address::new_p2pkh()
    };

    script_execution_engine
        .execute::<SIG_LEN / 2 + PK_LEN / 2 + 25 + 2, N_OUTPUT_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN, N_INPUT_SIZE, OPCODES_AMOUNT, 26, 0>(
            script,
            address,
            [],
            Option::none(),
        );

    script_execution_engine.stack.op_verify()
}

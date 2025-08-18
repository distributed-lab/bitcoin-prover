mod globals;

use bvm::stack::{empty_stack_array, Stack};
use globals::{
    CODESEPARATOR_REDEEM_SCRIPT_LEN, CODESEPARATOR_REDEEM_SCRIPT_LEN_LEN, CUR_IS_GEGWIT,
    CUR_TX_INP_COUNT, CUR_TX_INP_COUNT_LEN, CUR_TX_INP_SIZE, CUR_TX_LEN,
    CUR_TX_MAX_WITNESS_STACK_SIZE, CUR_TX_OUT_COUNT, CUR_TX_OUT_COUNT_LEN, CUR_TX_OUT_SIZE,
    CUR_TX_WITNESS_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN, INPUT_WITNESS_LEN,
    MAX_STACK_ELEMENT_SIZE, N_INPUT_SIZE, N_OUTPUT_SIZE, OPCODES_AMOUNT, PREV_IS_GEGWIT,
    PREV_TX_INP_COUNT, PREV_TX_INP_COUNT_LEN, PREV_TX_INP_SIZE, PREV_TX_LEN,
    PREV_TX_MAX_WITNESS_STACK_SIZE, PREV_TX_OUT_COUNT, PREV_TX_OUT_COUNT_LEN, PREV_TX_OUT_SIZE,
    PREV_TX_WITNESS_SIZE, REDEEM_SCRIPT_LEN, REDEEM_SCRIPT_OPCODES_AMOUNT, SCRIPT_PUB_KEY_LEN,
    SCRIPT_SIG_LEN, STACK_SIZE,
};
use script::execution::ScriptExecutionEngine;
use sign::{
    address::Address,
    compact_size::{self, u32_to_compact_size_array},
    transaction::Transaction,
};
use utils::convert::{bytes_to_hex, hex_to_bytes, le_bytes_to_u32};

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

    let mut redeem_script = [0; REDEEM_SCRIPT_LEN];
    let mut codeseparator_redeem_script = [0; CODESEPARATOR_REDEEM_SCRIPT_LEN];
    let script_sig_bytes = hex_to_bytes(script_sig);

    if CUR_IS_GEGWIT {
        assert(prev_tx.data[script_pub_key_pos] == 0);
        assert(SCRIPT_PUB_KEY_LEN == 35);
        script_pub_key[0] = 168;
        for i in 1..34 {
            script_pub_key[i] = prev_tx.data[script_pub_key_pos + i];
        }
        script_pub_key[34] = 135;

        let size_offset = cur_tx.witness.unwrap()[input_to_sign].stack_size.offset;
        let size = compact_size::get_compact_size(cur_tx.data, size_offset);
        let size_u32 = compact_size::compact_size_to_u32(cur_tx.data, size);

        let rds_offset =
            cur_tx.witness.unwrap()[input_to_sign].items.get(size_u32 - 1).unwrap().item.offset;
        for i in 0..REDEEM_SCRIPT_LEN {
            redeem_script[i] = cur_tx.data[rds_offset + i];
        }
    } else {
        assert(SCRIPT_PUB_KEY_LEN == 23);
        for i in 0..SCRIPT_PUB_KEY_LEN {
            script_pub_key[i] = prev_tx.data[script_pub_key_pos + i];
        }

        for i in 0..REDEEM_SCRIPT_LEN {
            redeem_script[REDEEM_SCRIPT_LEN - 1 - i] =
                script_sig_bytes[(SCRIPT_SIG_LEN / 2) - 1 - i];
        }
    }

    for i in 0..CODESEPARATOR_REDEEM_SCRIPT_LEN {
        codeseparator_redeem_script[CODESEPARATOR_REDEEM_SCRIPT_LEN - 1 - i] =
            redeem_script[REDEEM_SCRIPT_LEN - 1 - i];
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

    let address = if CUR_IS_GEGWIT {
        Address::new_p2wsh()
    } else {
        Address::new_p2sh()
    };

    if !CUR_IS_GEGWIT {
        script_execution_engine
            .execute::<SCRIPT_SIG_LEN / 2, N_OUTPUT_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN, N_INPUT_SIZE, OPCODES_AMOUNT, 0, 0>(
                script_sig_bytes,
                address,
                [],
                Option::none(),
            );
    } else {
        let mut witness = [0; INPUT_WITNESS_LEN];
        let witness_input_offset =
            cur_tx.witness.unwrap()[input_to_sign].items.get(0).unwrap().size.offset;
        for i in 0..INPUT_WITNESS_LEN {
            witness[i] = cur_tx.data[witness_input_offset + i];
        }
        script_execution_engine.add_witness_to_stack(witness);
    }

    println(bytes_to_hex(script_pub_key));

    script_execution_engine
        .execute::<SCRIPT_PUB_KEY_LEN, N_OUTPUT_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN, N_INPUT_SIZE, 3, 0, 0>(
            script_pub_key,
            address,
            [],
            Option::none(),
        );

    assert(script_execution_engine.stack.op_verify());

    script_execution_engine
        .execute::<REDEEM_SCRIPT_LEN, N_OUTPUT_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN, N_INPUT_SIZE, REDEEM_SCRIPT_OPCODES_AMOUNT, 0, 0>(
            redeem_script,
            address,
            [],
            Option::none(),
        );

    script_execution_engine.stack.op_verify()
}

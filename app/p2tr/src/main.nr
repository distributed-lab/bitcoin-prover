mod globals;

use crypto::schnorr::schnorr_verify;
use globals::{
    CUR_IS_GEGWIT, CUR_TX_INP_COUNT, CUR_TX_INP_COUNT_LEN, CUR_TX_INP_SIZE, CUR_TX_LEN,
    CUR_TX_MAX_WITNESS_STACK_SIZE, CUR_TX_OUT_COUNT, CUR_TX_OUT_COUNT_LEN, CUR_TX_OUT_SIZE,
    CUR_TX_WITNESS_SIZE, N_OUTPUT_SIZE, PREV_IS_GEGWIT, PREV_TX_INP_COUNT, PREV_TX_INP_COUNT_LEN,
    PREV_TX_INP_SIZE, PREV_TX_LEN, PREV_TX_MAX_WITNESS_STACK_SIZE, PREV_TX_OUT_COUNT,
    PREV_TX_OUT_COUNT_LEN, PREV_TX_OUT_SIZE, PREV_TX_WITNESS_SIZE, SIGNATURE_LEN, UTXOS_LEN,
};
use sign::{
    sig_types::{SIGHASH_ALL, SIGHASH_ANYONECANPAY, SIGHASH_NONE, SIGHASH_SINGLE},
    taproot::{
        serialize_p2tr_sighash_all, serialize_p2tr_sighash_all_anyonecanpay,
        serialize_p2tr_sighash_none, serialize_p2tr_sighash_none_anyonecanpay,
        serialize_p2tr_sighash_single, serialize_p2tr_sighash_single_anyonecanpay,
    },
    transaction::{Output, Transaction},
};
use utils::convert::{hex_to_bytes, le_bytes_to_u32};

// Key path spend
fn main(
    cur_tx_data: str<CUR_TX_LEN>,
    prev_tx_data: str<PREV_TX_LEN>,
    utxos_pos: [Output; CUR_TX_INP_COUNT],
    utxos_data: [u8; UTXOS_LEN],
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

    let vout_pos = cur_tx.inputs[input_to_sign].vout.offset;
    let mut vout_bytes = [0; 4];
    for i in 0..4 {
        vout_bytes[i] = cur_tx.data[vout_pos + i];
    }

    let vout = le_bytes_to_u32(vout_bytes);
    let n_utxo_offset = prev_tx.outputs[vout].amount.offset;
    let script_pub_key_offset = prev_tx.outputs[vout].script_pub_key.offset;

    assert(script_pub_key_offset + prev_tx.outputs[vout].script_pub_key.size - n_utxo_offset == 43);

    // 8 + 1 + 34 (amount + spk_len + spk)
    let mut n_utxo = [0; 43];
    let mut pub_key = [0; 32];

    for i in 0..43 {
        n_utxo[i] = prev_tx.data[n_utxo_offset + i];
    }

    for i in 0..32 {
        pub_key[i] = prev_tx.data[script_pub_key_offset + i + 2];
    }

    let mut signature = [0; 64];
    let signature_offset = cur_tx.witness.unwrap()[input_to_sign].items.get(0).unwrap().item.offset;

    for i in 0..64 {
        signature[i] = cur_tx.data[signature_offset + i];
    }

    let sigtype = if SIGNATURE_LEN == 64 {
        0x01
    } else {
        cur_tx.data[signature_offset + 64]
    };

    let message = if sigtype == SIGHASH_ALL {
        serialize_p2tr_sighash_all(
            cur_tx,
            input_to_sign,
            0,
            utxos_pos,
            utxos_data,
            Option::none(),
            Option::none(),
        )
    } else if sigtype == SIGHASH_NONE {
        serialize_p2tr_sighash_none(
            cur_tx,
            input_to_sign,
            0,
            utxos_pos,
            utxos_data,
            Option::none(),
            Option::none(),
        )
    } else if sigtype == SIGHASH_SINGLE {
        serialize_p2tr_sighash_single::<CUR_TX_LEN / 2, CUR_TX_INP_COUNT, CUR_TX_INP_COUNT_LEN, CUR_TX_INP_SIZE, CUR_TX_OUT_COUNT, CUR_TX_OUT_COUNT_LEN, CUR_TX_OUT_SIZE, CUR_TX_MAX_WITNESS_STACK_SIZE, CUR_TX_WITNESS_SIZE, UTXOS_LEN, N_OUTPUT_SIZE>(
            cur_tx,
            input_to_sign,
            0,
            utxos_pos,
            utxos_data,
            Option::none(),
            Option::none(),
        )
    } else if sigtype == (SIGHASH_ALL | SIGHASH_ANYONECANPAY) {
        serialize_p2tr_sighash_all_anyonecanpay(
            cur_tx,
            input_to_sign,
            0,
            n_utxo,
            Option::none(),
            Option::none(),
        )
    } else if sigtype == (SIGHASH_NONE | SIGHASH_ANYONECANPAY) {
        serialize_p2tr_sighash_none_anyonecanpay(
            cur_tx,
            input_to_sign,
            0,
            n_utxo,
            Option::none(),
            Option::none(),
        )
    } else if sigtype == (SIGHASH_SINGLE | SIGHASH_ANYONECANPAY) {
        serialize_p2tr_sighash_single_anyonecanpay::<CUR_TX_LEN / 2, CUR_TX_INP_COUNT, CUR_TX_INP_COUNT_LEN, CUR_TX_INP_SIZE, CUR_TX_OUT_COUNT, CUR_TX_OUT_COUNT_LEN, CUR_TX_OUT_SIZE, CUR_TX_MAX_WITNESS_STACK_SIZE, CUR_TX_WITNESS_SIZE, N_OUTPUT_SIZE>(
            cur_tx,
            input_to_sign,
            0,
            n_utxo,
            Option::none(),
            Option::none(),
        )
    } else {
        assert(false, "Unknown sighash type");
        [0; 32]
    };

    schnorr_verify(pub_key, message, signature)
}

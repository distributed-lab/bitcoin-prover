use crate::transaction::Transaction;
use dep::bignum::{BigNum, U256};
use crypto::ecdsa::ecdsa_verify;
use utils::convert::{bytes_to_hex, hex_to_bytes, u32_to_le_bytes};

fn prepare_preimage_hash_for_sighash_all<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let SCRIPT_PUB_KEY_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    script_pub_key: [u8; SCRIPT_PUB_KEY_SIZE],
) -> [u8; 4 + INPUT_SIZE + OUTPUT_SIZE + 4 + SCRIPT_PUB_KEY_SIZE + 4 - 1] {
    let mut data = [0; 4 + INPUT_SIZE + OUTPUT_SIZE + 4 + SCRIPT_PUB_KEY_SIZE + 4 - 1];
    let mut data_pos: u32 = 0;

    for i in 0..4 {
        data[data_pos] = transaction.data[i];
        data_pos += 1;
    }

    let mut transaction_offset = transaction.input_count.offset;
    let i_when_change_offset = transaction.inputs[input_to_sign].script_sig_size.offset;
    let i_change_offset = transaction.inputs[input_to_sign].script_sig_size.size;

    for i in 0..(INPUT_SIZE - 1) {
        if transaction_offset + i == i_when_change_offset {
            for j in 0..SCRIPT_PUB_KEY_SIZE {
                data[data_pos] = script_pub_key[j];
                data_pos += 1;
            }

            transaction_offset += i_change_offset;
        }

        data[data_pos] = transaction.data[transaction_offset + i];
        data_pos += 1;
    }

    transaction_offset = transaction.output_count.offset;

    for i in 0..OUTPUT_SIZE {
        data[data_pos] = transaction.data[transaction_offset + i];
        data_pos += 1;
    }

    transaction_offset = transaction.output_count.offset + OUTPUT_SIZE + WITNESS_SIZE;

    for i in 0..4 {
        data[data_pos] = transaction.data[transaction_offset + i];
        data_pos += 1;
    }

    data[data_pos] = 0x01;
    data[data_pos + 1] = 0x00;
    data[data_pos + 2] = 0x00;
    data[data_pos + 3] = 0x00;

    data_pos += 4;

    assert(data_pos == 4 + INPUT_SIZE + OUTPUT_SIZE + 4 + SCRIPT_PUB_KEY_SIZE + 4 - 1);

    data
}

pub fn serialize_sighash_all<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let SCRIPT_PUB_KEY_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    // script_pub_key should contain script_pub_key_size along with the script_pub_key
    script_pub_key: [u8; SCRIPT_PUB_KEY_SIZE],
) -> [u8; 32] {
    assert(input_to_sign < INPUT_COUNT);

    // The transaction should contain empty script_sigs
    for i in 0..INPUT_COUNT {
        assert(transaction.inputs[i].script_sig.size == 0);
    }

    let transaction_data =
        prepare_preimage_hash_for_sighash_all(transaction, input_to_sign, script_pub_key);

    let hashed_transaction = sha256::digest(sha256::digest(transaction_data));

    hashed_transaction
}

fn prepare_preimage_hash_for_sighash_all_anyonecanpay<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let SCRIPT_PUB_KEY_SIZE: u32, let N_INPUT_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    script_pub_key: [u8; SCRIPT_PUB_KEY_SIZE],
) -> [u8; 4 + 1 + N_INPUT_SIZE + OUTPUT_SIZE + 4 + SCRIPT_PUB_KEY_SIZE + 4 - 1] {
    let mut data = [0; 4 + 1 + N_INPUT_SIZE + OUTPUT_SIZE + 4 + SCRIPT_PUB_KEY_SIZE + 4 - 1];
    let mut data_pos: u32 = 0;

    for i in 0..4 {
        data[data_pos] = transaction.data[i];
        data_pos += 1;
    }

    data[data_pos] = 1;
    data_pos += 1;

    let mut transaction_offset = transaction.inputs[input_to_sign].txid.offset;

    for i in 0..(N_INPUT_SIZE - 1) {
        if i == 36 {
            for j in 0..SCRIPT_PUB_KEY_SIZE {
                data[data_pos] = script_pub_key[j];
                data_pos += 1;
            }
            transaction_offset += 1;
        }

        data[data_pos] = transaction.data[transaction_offset + i];
        data_pos += 1;
    }

    transaction_offset = transaction.output_count.offset;

    for i in 0..OUTPUT_SIZE {
        data[data_pos] = transaction.data[transaction_offset + i];
        data_pos += 1;
    }

    transaction_offset = transaction.output_count.offset + OUTPUT_SIZE + WITNESS_SIZE;

    for i in 0..4 {
        data[data_pos] = transaction.data[transaction_offset + i];
        data_pos += 1;
    }

    data[data_pos] = 0x81;
    data[data_pos + 1] = 0x00;
    data[data_pos + 2] = 0x00;
    data[data_pos + 3] = 0x00;

    data_pos += 4;

    assert(data_pos == 4 + 1 + N_INPUT_SIZE + OUTPUT_SIZE + 4 + SCRIPT_PUB_KEY_SIZE + 4 - 1);

    data
}

pub fn serialize_sighash_all_anyonecanpay<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let SCRIPT_PUB_KEY_SIZE: u32, let N_INPUT_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    // script_pub_key should contain script_pub_key_size along with the script_pub_key
    script_pub_key: [u8; SCRIPT_PUB_KEY_SIZE],
) -> [u8; 32] {
    assert(input_to_sign < INPUT_COUNT);

    // The transaction should contain empty script_sigs
    for i in 0..INPUT_COUNT {
        assert(transaction.inputs[i].script_sig.size == 0);
    }

    let transaction_data = prepare_preimage_hash_for_sighash_all_anyonecanpay::<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE, SCRIPT_PUB_KEY_SIZE, N_INPUT_SIZE>(
        transaction,
        input_to_sign,
        script_pub_key,
    );

    let hashed_transaction = sha256::digest(sha256::digest(transaction_data));

    hashed_transaction
}

fn prepare_preimage_hash_for_sighash_single<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let SCRIPT_PUB_KEY_SIZE: u32, let N_OUTPUT_SIZE: u32, let INPUT_TO_SIGN: u32, let INPUT_TO_SIGN_LEN: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    script_pub_key: [u8; SCRIPT_PUB_KEY_SIZE],
    ) -> [u8; 4 + INPUT_SIZE + INPUT_TO_SIGN_LEN + ((INPUT_TO_SIGN) * 9) + N_OUTPUT_SIZE + 4 + SCRIPT_PUB_KEY_SIZE + 4 - 1] {
    assert(input_to_sign == INPUT_TO_SIGN);

    let mut data = [
        0; 4
            + INPUT_SIZE
            + INPUT_TO_SIGN_LEN
            + ((INPUT_TO_SIGN) * 9)
            + N_OUTPUT_SIZE
            + 4
            + SCRIPT_PUB_KEY_SIZE
            + 4
            - 1
    ];
    let mut data_pos: u32 = 0;

    for i in 0..4 {
        data[data_pos] = transaction.data[i];
        data_pos += 1;
    }

    let mut transaction_offset = transaction.input_count.offset;
    let i_when_change_offset = transaction.inputs[input_to_sign].script_sig_size.offset;
    let i_change_offset = transaction.inputs[input_to_sign].script_sig_size.size;

    for i in 0..(INPUT_SIZE - 1) {
        if transaction_offset + i == i_when_change_offset {
            for j in 0..SCRIPT_PUB_KEY_SIZE {
                data[data_pos] = script_pub_key[j];
                data_pos += 1;
            }

            transaction_offset += i_change_offset;
        }

        if (i >= INPUT_COUNT_LEN) {
            if (((i - INPUT_COUNT_LEN + 1) % 41 >= 36) & ((i - INPUT_COUNT_LEN + 1) % 41 <= 40))
                & !((i - INPUT_COUNT_LEN + 1) / 41 == input_to_sign) {
                data[data_pos] = 0;
            } else {
                data[data_pos] = transaction.data[transaction_offset + i];
            }
        } else {
            data[data_pos] = transaction.data[transaction_offset + i];
        }

        data_pos += 1;
    }

    transaction_offset = transaction.output_count.offset;

    let len = u32_to_le_bytes(INPUT_TO_SIGN_LEN);
    for i in 0..INPUT_TO_SIGN_LEN {
        data[data_pos] = len[i];
        data_pos += 1;
    }

    transaction_offset += INPUT_TO_SIGN_LEN;

    for _ in 0..(INPUT_TO_SIGN) {
        for _ in 0..8 {
            data[data_pos] = 0xff;
            data_pos += 1;
        }

        data[data_pos] = 0;
        data_pos += 1;
    }

    transaction_offset = transaction.outputs[input_to_sign].amount.offset;

    for i in 0..N_OUTPUT_SIZE {
        data[data_pos] = transaction.data[transaction_offset + i];
        data_pos += 1;
    }

    transaction_offset = transaction_offset + N_OUTPUT_SIZE + WITNESS_SIZE;

    for i in 0..4 {
        data[data_pos] = transaction.data[transaction_offset + i];
        data_pos += 1;
    }

    data[data_pos] = 0x03;
    data[data_pos + 1] = 0x00;
    data[data_pos + 2] = 0x00;
    data[data_pos + 3] = 0x00;

    data_pos += 4;

    assert(
        data_pos
            == 4
                + INPUT_SIZE
                + INPUT_TO_SIGN_LEN
                + ((INPUT_TO_SIGN) * 9)
                + N_OUTPUT_SIZE
                + 4
                + SCRIPT_PUB_KEY_SIZE
                + 4
                - 1,
    );

    data
}

pub fn serialize_sighash_single<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let SCRIPT_PUB_KEY_SIZE: u32, let N_OUTPUT_SIZE: u32, let INPUT_TO_SIGN: u32, let INPUT_TO_SIGN_LEN: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    // script_pub_key should contain script_pub_key_size along with the script_pub_key
    script_pub_key: [u8; SCRIPT_PUB_KEY_SIZE],
) -> [u8; 32] {
    assert(input_to_sign < INPUT_COUNT);
    assert(OUTPUT_COUNT > input_to_sign);

    // The transaction should contain empty script_sigs
    for i in 0..INPUT_COUNT {
        assert(transaction.inputs[i].script_sig.size == 0);
    }

    let transaction_data = prepare_preimage_hash_for_sighash_single::<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE, SCRIPT_PUB_KEY_SIZE, N_OUTPUT_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN>(
        transaction,
        input_to_sign,
        script_pub_key,
    );

    let hashed_transaction = sha256::digest(sha256::digest(transaction_data));

    hashed_transaction
}

fn prepare_preimage_hash_for_sighash_single_anyonecanpay<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let SCRIPT_PUB_KEY_SIZE: u32, let N_OUTPUT_SIZE: u32, let INPUT_TO_SIGN: u32, let INPUT_TO_SIGN_LEN: u32, let N_INPUT_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    script_pub_key: [u8; SCRIPT_PUB_KEY_SIZE],
    ) -> [u8; 4 + 1 + N_INPUT_SIZE + INPUT_TO_SIGN_LEN + ((INPUT_TO_SIGN) * 9) + N_OUTPUT_SIZE + 4 + SCRIPT_PUB_KEY_SIZE + 4 - 1] {
    assert(input_to_sign == INPUT_TO_SIGN);

    let mut data = [
        0; 4
            + 1
            + N_INPUT_SIZE
            + INPUT_TO_SIGN_LEN
            + ((INPUT_TO_SIGN) * 9)
            + N_OUTPUT_SIZE
            + 4
            + SCRIPT_PUB_KEY_SIZE
            + 4
            - 1
    ];
    let mut data_pos: u32 = 0;

    for i in 0..4 {
        data[data_pos] = transaction.data[i];
        data_pos += 1;
    }

    data[data_pos] = 1;
    data_pos += 1;

    let mut transaction_offset = transaction.inputs[input_to_sign].txid.offset;

    for i in 0..(N_INPUT_SIZE - 1) {
        if i == 36 {
            for j in 0..SCRIPT_PUB_KEY_SIZE {
                data[data_pos] = script_pub_key[j];
                data_pos += 1;
            }

            transaction_offset += 1;
        }

        data[data_pos] = transaction.data[transaction_offset + i];
        data_pos += 1;
    }

    transaction_offset = transaction.output_count.offset;

    let len = u32_to_le_bytes(INPUT_TO_SIGN_LEN);
    for i in 0..INPUT_TO_SIGN_LEN {
        data[data_pos] = len[i];
        data_pos += 1;
    }

    for _ in 0..(INPUT_TO_SIGN) {
        for _ in 0..8 {
            data[data_pos] = 0xff;
            data_pos += 1;
        }

        data[data_pos] = 0;
        data_pos += 1;
    }

    transaction_offset = transaction.outputs[input_to_sign].amount.offset;

    for i in 0..N_OUTPUT_SIZE {
        data[data_pos] = transaction.data[transaction_offset + i];
        data_pos += 1;
    }

    transaction_offset = transaction_offset + N_OUTPUT_SIZE + WITNESS_SIZE;

    for i in 0..4 {
        data[data_pos] = transaction.data[transaction_offset + i];
        data_pos += 1;
    }

    data[data_pos] = 0x83;
    data[data_pos + 1] = 0x00;
    data[data_pos + 2] = 0x00;
    data[data_pos + 3] = 0x00;

    data_pos += 4;

    assert(
        data_pos
            == 4
                + 1
                + N_INPUT_SIZE
                + INPUT_TO_SIGN_LEN
                + ((INPUT_TO_SIGN) * 9)
                + N_OUTPUT_SIZE
                + 4
                + SCRIPT_PUB_KEY_SIZE
                + 4
                - 1,
    );

    data
}

pub fn serialize_sighash_single_anyonecanpay<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let SCRIPT_PUB_KEY_SIZE: u32, let N_OUTPUT_SIZE: u32, let INPUT_TO_SIGN: u32, let INPUT_TO_SIGN_LEN: u32, let N_INPUT_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    // script_pub_key should contain script_pub_key_size along with the script_pub_key
    script_pub_key: [u8; SCRIPT_PUB_KEY_SIZE],
) -> [u8; 32] {
    assert(input_to_sign < INPUT_COUNT);
    assert(OUTPUT_COUNT > input_to_sign);

    // The transaction should contain empty script_sigs
    for i in 0..INPUT_COUNT {
        assert(transaction.inputs[i].script_sig.size == 0);
    }

    let transaction_data = prepare_preimage_hash_for_sighash_single_anyonecanpay::<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE, SCRIPT_PUB_KEY_SIZE, N_OUTPUT_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN, N_INPUT_SIZE>(
        transaction,
        input_to_sign,
        script_pub_key,
    );

    let hashed_transaction = sha256::digest(sha256::digest(transaction_data));

    hashed_transaction
}

fn prepare_preimage_hash_for_sighash_none<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let SCRIPT_PUB_KEY_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    script_pub_key: [u8; SCRIPT_PUB_KEY_SIZE],
) -> [u8; 4 + INPUT_SIZE + 1 + 4 + SCRIPT_PUB_KEY_SIZE + 4 - 1] {
    let mut data = [0; 4 + INPUT_SIZE + 1 + 4 + SCRIPT_PUB_KEY_SIZE + 4 - 1];
    let mut data_pos: u32 = 0;

    for i in 0..4 {
        data[data_pos] = transaction.data[i];
        data_pos += 1;
    }

    let mut transaction_offset = transaction.input_count.offset;
    let i_when_change_offset = transaction.inputs[input_to_sign].script_sig_size.offset;
    let i_change_offset = transaction.inputs[input_to_sign].script_sig_size.size;

    for i in 0..(INPUT_SIZE - 1) {
        if transaction_offset + i == i_when_change_offset {
            for j in 0..SCRIPT_PUB_KEY_SIZE {
                data[data_pos] = script_pub_key[j];
                data_pos += 1;
            }

            transaction_offset += i_change_offset;
        }

        if (i >= INPUT_COUNT_LEN) {
            if (((i - INPUT_COUNT_LEN + 1) % 41 >= 36) & ((i - INPUT_COUNT_LEN + 1) % 41 <= 40))
                & !((i - INPUT_COUNT_LEN + 1) / 41 == input_to_sign) {
                data[data_pos] = 0;
            } else {
                data[data_pos] = transaction.data[transaction_offset + i];
            }
        } else {
            data[data_pos] = transaction.data[transaction_offset + i];
        }

        data_pos += 1;
    }

    data[data_pos] = 0;
    data_pos += 1;

    transaction_offset = transaction.output_count.offset + OUTPUT_SIZE + WITNESS_SIZE;

    for i in 0..4 {
        data[data_pos] = transaction.data[transaction_offset + i];
        data_pos += 1;
    }

    data[data_pos] = 0x02;
    data[data_pos + 1] = 0x00;
    data[data_pos + 2] = 0x00;
    data[data_pos + 3] = 0x00;

    data_pos += 4;

    assert(data_pos == 4 + INPUT_SIZE + 1 + 4 + SCRIPT_PUB_KEY_SIZE + 4 - 1);

    data
}

pub fn serialize_sighash_none<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let SCRIPT_PUB_KEY_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    // script_pub_key should contain script_pub_key_size along with the script_pub_key
    script_pub_key: [u8; SCRIPT_PUB_KEY_SIZE],
) -> [u8; 32] {
    assert(input_to_sign < INPUT_COUNT);

    // The transaction should contain empty script_sigs
    for i in 0..INPUT_COUNT {
        assert(transaction.inputs[i].script_sig.size == 0);
    }

    let transaction_data =
        prepare_preimage_hash_for_sighash_none(transaction, input_to_sign, script_pub_key);

    let hashed_transaction = sha256::digest(sha256::digest(transaction_data));

    hashed_transaction
}

fn prepare_preimage_hash_for_sighash_none_anyonecanpay<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let SCRIPT_PUB_KEY_SIZE: u32, let N_INPUT_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    script_pub_key: [u8; SCRIPT_PUB_KEY_SIZE],
) -> [u8; 4 + 1 + N_INPUT_SIZE + 1 + 4 + SCRIPT_PUB_KEY_SIZE + 4 - 1] {
    let mut data = [0; 4 + 1 + N_INPUT_SIZE + 1 + 4 + SCRIPT_PUB_KEY_SIZE + 4 - 1];
    let mut data_pos: u32 = 0;

    for i in 0..4 {
        data[data_pos] = transaction.data[i];
        data_pos += 1;
    }

    data[data_pos] = 1;
    data_pos += 1;

    let mut transaction_offset = transaction.inputs[input_to_sign].txid.offset;

    for i in 0..(N_INPUT_SIZE - 1) {
        if i == 36 {
            for j in 0..SCRIPT_PUB_KEY_SIZE {
                data[data_pos] = script_pub_key[j];
                data_pos += 1;
            }
            transaction_offset += 1;
        }

        data[data_pos] = transaction.data[transaction_offset + i];
        data_pos += 1;
    }

    data[data_pos] = 0;
    data_pos += 1;

    transaction_offset = transaction.output_count.offset + OUTPUT_SIZE + WITNESS_SIZE;

    for i in 0..4 {
        data[data_pos] = transaction.data[transaction_offset + i];
        data_pos += 1;
    }

    data[data_pos] = 0x82;
    data[data_pos + 1] = 0x00;
    data[data_pos + 2] = 0x00;
    data[data_pos + 3] = 0x00;

    data_pos += 4;

    assert(data_pos == 4 + 1 + N_INPUT_SIZE + 1 + 4 + SCRIPT_PUB_KEY_SIZE + 4 - 1);

    data
}

pub fn serialize_sighash_none_anyonecanpay<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let SCRIPT_PUB_KEY_SIZE: u32, let N_INPUT_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    // script_pub_key should contain script_pub_key_size along with the script_pub_key
    script_pub_key: [u8; SCRIPT_PUB_KEY_SIZE],
) -> [u8; 32] {
    assert(input_to_sign < INPUT_COUNT);

    // The transaction should contain empty script_sigs
    for i in 0..INPUT_COUNT {
        assert(transaction.inputs[i].script_sig.size == 0);
    }

    let transaction_data = prepare_preimage_hash_for_sighash_none_anyonecanpay::<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE, SCRIPT_PUB_KEY_SIZE, N_INPUT_SIZE>(
        transaction,
        input_to_sign,
        script_pub_key,
    );

    let hashed_transaction = sha256::digest(sha256::digest(transaction_data));

    hashed_transaction
}

#[test]
fn test_serialize_legacy_transaction_sighash_all() {
    let string = "0100000001b7994a0db2f373a29227e1d90da883c6ce1cb0dd2d6812e4558041ebbbcfa54b0000000000ffffffff01983a0000000000001976a914b3e2819b6262e0b1f19fc7229d75677f347c91ac88ac00000000";
    let bytes = hex_to_bytes(string);
    let transaction = Transaction::<85, 1, 1, 42, 1, 1, 35, 1, 0>::new(bytes, false);

    // script_pub_key should contain script_pub_key_size along with the script_pub_key
    let script_pub_key = "1976a9144299ff317fcd12ef19047df66d72454691797bfc88ac";
    let script_pub_key_bytes = hex_to_bytes(script_pub_key);

    let sighash_all_transaction_bytes = serialize_sighash_all(transaction, 0, script_pub_key_bytes);

    let sighash_all_transaction = bytes_to_hex(sighash_all_transaction_bytes);

    assert(
        sighash_all_transaction
            == "a6b4103f527dfe43dfbadf530c247bac8a98b7463c7c6ad38eed97021d18ffcb",
    );
}

#[test]
fn test_serialize_segwit_transaction_sighash_all() {
    let string = "0200000000010192f29384a956361b9b9ebc667d01489cb360068c22c7b89396e5fdc3ece0305a0100000000ffffffff023d0500000000000016001464193f85b629823f114c9d997ee68627d7395d5fe7a1000000000000160014d0446764c4f16f78ca0ce0b7f487cc5fe205835e024730440220598ef97f63f7648e39d03ff58383056322fa13effaee8d11c9c9e8789a72522002204dda5bbc9cba008682d62820395a2c43b9abae52d6ad81835e72bda09468fa21012103d9a4d0bbe47d58b68e366a380107ba3470f6893764a2d020127d36c169df850100000000";
    let bytes = hex_to_bytes(string);
    let transaction = Transaction::<222, 1, 1, 42, 2, 1, 63, 2, 107>::new(bytes, true);
    let script_pub_key = "1976a9144299ff317fcd12ef19047df66d72454691797bfc88ac";
    let script_pub_key_bytes = hex_to_bytes(script_pub_key);

    let sighash_all_transaction_bytes = serialize_sighash_all(transaction, 0, script_pub_key_bytes);

    let sighash_all_transaction = bytes_to_hex(sighash_all_transaction_bytes);

    assert(
        sighash_all_transaction
            == "39e3884c3761427b3a7eee244fc1495036a9f2dad35cfbfc0abbac2455f6bf26",
    );
}

// #[test]
// fn test_serialize_legacy_transaction_sighash_single() {
//     // txid: 99fc1e5c753459808bac56435b3d45f2fcf0dd73016ea14460d63e9ddf353714
//     let string = "01000000056c499afac2e1a63bb6b9461a337319b970c13c2c77be53ebc1c7c870059334000800000000ffffffff00e16741107dcd7cfa2eaeb7d767e47edbec577511b3e10f16980754c3493b090900000000ffffffff078f6ec6d77fc7e0200e12fc1e2114e56e1c5bfc869d376a87b0a1bc5f8dc50e0800000000ffffffff64289405350c34a437566b764989b50381f68cf208531c54cb205f4e859e22100800000000ffffffff291cd5940ac16559eef5a2f2b4770271959f2007b45a0d850ef5d35d134df4100900000000ffffffff010000000000000000266a24e4b883e5bda9e7a59ee4bb99e9b1bcf09f909f426974636f696e20746f20506c75746f2100000000";
//     let bytes = hex_to_bytes(string);
//     let transaction = Transaction::<262, 5, 1, 206, 1, 1, 48, 1, 0>::new(bytes, false);

//     // script_pub_key should contain script_pub_key_size along with the script_pub_key
//     let script_pub_key = "1976a9140fb87a5071385b6976397d1c53ee16f09139a33488ac";
//     let script_pub_key_bytes = hex_to_bytes(script_pub_key);

//     let sighash_single_transaction_bytes = serialize_sighash_single::<262, 5, 1, 206, 1, 1, 48, 1, 0, 26, 47, 0, 1>(
//         transaction,
//         0,
//         script_pub_key_bytes,
//     );

//     let sighash_single_transaction = sighash_single_transaction_bytes;

//     // pk: 044edfcf9dfe6c0b5c83d1ab3f78d1b39a46ebac6798e08e19761f5ed89ec83c108172c4776865f02047b39cd704135c00c1b00085e0d1b9255405ac7079fa50a2
//     let public_key = hex_to_bytes(
//         "044edfcf9dfe6c0b5c83d1ab3f78d1b39a46ebac6798e08e19761f5ed89ec83c108172c4776865f02047b39cd704135c00c1b00085e0d1b9255405ac7079fa50a2",
//     );

//     let sig = hex_to_bytes(
//         (
//             "30450221008db24ef816a943c1a53263bcee8a4fe91c6c3c8300d81ac30129683d2e3c029d0220433b714fbc5ba80227e192cd9c1bcd6e268d6d557fecaf76d476aee462ae9012"
//         ),
//     );

//     assert(ecdsa_verify(sig, public_key, sighash_single_transaction));
// }

// todo: Write proper test assertions - currently only checking that no panics occur
#[test]
fn test_serialize_legacy_transaction_sighash_none() {
    let string = "01000000056c499afac2e1a63bb6b9461a337319b970c13c2c77be53ebc1c7c870059334000800000000ffffffff00e16741107dcd7cfa2eaeb7d767e47edbec577511b3e10f16980754c3493b090900000000ffffffff078f6ec6d77fc7e0200e12fc1e2114e56e1c5bfc869d376a87b0a1bc5f8dc50e0800000000ffffffff64289405350c34a437566b764989b50381f68cf208531c54cb205f4e859e22100800000000ffffffff291cd5940ac16559eef5a2f2b4770271959f2007b45a0d850ef5d35d134df4100900000000ffffffff010000000000000000266a24e4b883e5bda9e7a59ee4bb99e9b1bcf09f909f426974636f696e20746f20506c75746f2100000000";
    let bytes = hex_to_bytes(string);
    let transaction = Transaction::<262, 5, 1, 206, 1, 1, 48, 1, 0>::new(bytes, false);

    // script_pub_key should contain script_pub_key_size along with the script_pub_key
    let script_pub_key = "1976a9140fb87a5071385b6976397d1c53ee16f09139a33488ac";
    let script_pub_key_bytes = hex_to_bytes(script_pub_key);

    let sighash = serialize_sighash_none(transaction, 0, script_pub_key_bytes);

    assert(
        bytes_to_hex(sighash) == "809a85f9e793e9cb66866db039e8753402dcf6bc5b65893ffaccb2746e499ebe",
    );
}

// todo: Write proper test assertions - currently only checking that no panics occur
#[test]
fn test_serialize_legacy_transaction_sighash_all_anyonecanpay() {
    let string = "01000000056c499afac2e1a63bb6b9461a337319b970c13c2c77be53ebc1c7c870059334000800000000ffffffff00e16741107dcd7cfa2eaeb7d767e47edbec577511b3e10f16980754c3493b090900000000ffffffff078f6ec6d77fc7e0200e12fc1e2114e56e1c5bfc869d376a87b0a1bc5f8dc50e0800000000ffffffff64289405350c34a437566b764989b50381f68cf208531c54cb205f4e859e22100800000000ffffffff291cd5940ac16559eef5a2f2b4770271959f2007b45a0d850ef5d35d134df4100900000000ffffffff010000000000000000266a24e4b883e5bda9e7a59ee4bb99e9b1bcf09f909f426974636f696e20746f20506c75746f2100000000";
    let bytes = hex_to_bytes(string);
    let transaction = Transaction::<262, 5, 1, 206, 1, 1, 48, 1, 0>::new(bytes, false);

    // script_pub_key should contain script_pub_key_size along with the script_pub_key
    let script_pub_key = "1976a9140fb87a5071385b6976397d1c53ee16f09139a33488ac";
    let script_pub_key_bytes = hex_to_bytes(script_pub_key);

    let sighash = serialize_sighash_all_anyonecanpay::<262, 5, 1, 206, 1, 1, 48, 1, 0, 26, 41>(
        transaction,
        0,
        script_pub_key_bytes,
    );

    assert(
        bytes_to_hex(sighash) == "376ce858de8118381de658dd3ad3e03b0b9f52931c75d40d5db37aa24a3e1a8b",
    );
}

// todo: Write proper test assertions - currently only checking that no panics occur
#[test]
fn test_serialize_legacy_transaction_sighash_single_anyonecanpay() {
    let string = "01000000056c499afac2e1a63bb6b9461a337319b970c13c2c77be53ebc1c7c870059334000800000000ffffffff00e16741107dcd7cfa2eaeb7d767e47edbec577511b3e10f16980754c3493b090900000000ffffffff078f6ec6d77fc7e0200e12fc1e2114e56e1c5bfc869d376a87b0a1bc5f8dc50e0800000000ffffffff64289405350c34a437566b764989b50381f68cf208531c54cb205f4e859e22100800000000ffffffff291cd5940ac16559eef5a2f2b4770271959f2007b45a0d850ef5d35d134df4100900000000ffffffff010000000000000000266a24e4b883e5bda9e7a59ee4bb99e9b1bcf09f909f426974636f696e20746f20506c75746f2100000000";
    let bytes = hex_to_bytes(string);
    let transaction = Transaction::<262, 5, 1, 206, 1, 1, 48, 1, 0>::new(bytes, false);

    // script_pub_key should contain script_pub_key_size along with the script_pub_key
    let script_pub_key = "1976a9140fb87a5071385b6976397d1c53ee16f09139a33488ac";
    let script_pub_key_bytes = hex_to_bytes(script_pub_key);

    let sighash = serialize_sighash_single_anyonecanpay::<262, 5, 1, 206, 1, 1, 48, 1, 0, 26, 47, 0, 1, 41>(
        transaction,
        0,
        script_pub_key_bytes,
    );

    assert(
        bytes_to_hex(sighash) == "316e41b505abf188d253bf38182692c8f282f2ae67f09306ed0f539a62503c70",
    );
}

// todo: Write proper test assertions - currently only checking that no panics occur
#[test]
fn test_serialize_legacy_transaction_sighash_none_anyonecanpay() {
    let string = "01000000056c499afac2e1a63bb6b9461a337319b970c13c2c77be53ebc1c7c870059334000800000000ffffffff00e16741107dcd7cfa2eaeb7d767e47edbec577511b3e10f16980754c3493b090900000000ffffffff078f6ec6d77fc7e0200e12fc1e2114e56e1c5bfc869d376a87b0a1bc5f8dc50e0800000000ffffffff64289405350c34a437566b764989b50381f68cf208531c54cb205f4e859e22100800000000ffffffff291cd5940ac16559eef5a2f2b4770271959f2007b45a0d850ef5d35d134df4100900000000ffffffff010000000000000000266a24e4b883e5bda9e7a59ee4bb99e9b1bcf09f909f426974636f696e20746f20506c75746f2100000000";
    let bytes = hex_to_bytes(string);
    let transaction = Transaction::<262, 5, 1, 206, 1, 1, 48, 1, 0>::new(bytes, false);

    // script_pub_key should contain script_pub_key_size along with the script_pub_key
    let script_pub_key = "1976a9140fb87a5071385b6976397d1c53ee16f09139a33488ac";
    let script_pub_key_bytes = hex_to_bytes(script_pub_key);

    let sighash = serialize_sighash_none_anyonecanpay::<262, 5, 1, 206, 1, 1, 48, 1, 0, 26, 41>(
        transaction,
        0,
        script_pub_key_bytes,
    );

    assert(
        bytes_to_hex(sighash) == "35c22dea04126559fa211d7efd28c3bc16435d02e54f460d28c436d1c1a3c22f",
    );
}

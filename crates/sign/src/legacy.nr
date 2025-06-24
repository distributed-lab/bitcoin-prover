use crate::transaction::Transaction;
use utils::convert::{bytes_to_hex, hex_to_bytes};

fn prepare_preimage_hash_for_sighash_all<let TRANSACTION_SIZE: u32, let INPUT_COUNT: u32, let INPUT_COUNT_LEN: u32, let INPUT_SIZE: u32, let OUTPUT_COUNT: u32, let OUTPUT_COUNT_LEN: u32, let OUTPUT_SIZE: u32, let MAX_WITNESS_STACK_SIZE: u32, let WITNESS_SIZE: u32, let SCRIPT_PUB_KEY_SIZE: u32>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, INPUT_COUNT_LEN, INPUT_SIZE, OUTPUT_COUNT, OUTPUT_COUNT_LEN, OUTPUT_SIZE, MAX_WITNESS_STACK_SIZE, WITNESS_SIZE>,
    input_to_sign: u32,
    script_pub_key: [u8; SCRIPT_PUB_KEY_SIZE],
) -> [u8; 4 + INPUT_SIZE + OUTPUT_SIZE + 4 + (SCRIPT_PUB_KEY_SIZE - 1) + 4] {
    let mut data = [0; 4 + INPUT_SIZE + OUTPUT_SIZE + 4 + (SCRIPT_PUB_KEY_SIZE - 1) + 4];
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

    assert(data_pos == 4 + INPUT_SIZE + OUTPUT_SIZE + 4 + (SCRIPT_PUB_KEY_SIZE - 1) + 4);

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

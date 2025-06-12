use crate::transaction::Transaction;
use utils::convert::{hex_to_bytes, bytes_to_hex_string};


fn insert_script_pub_key_and_hash_type<
    let TRANSACTION_SIZE: u32,
    let INPUT_COUNT: u32,
    let OUTPUT_COUNT: u32,
    let MAX_WITNESS_STACK_SIZE: u32,
    let SCRIPT_PUB_KEY_SIZE: u32,
> (
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, OUTPUT_COUNT, MAX_WITNESS_STACK_SIZE>,
    input_to_sign: u32,
    script_pub_key: [u8; SCRIPT_PUB_KEY_SIZE],
    hash_type: u8,
) -> [u8; TRANSACTION_SIZE - 1 + SCRIPT_PUB_KEY_SIZE + 4] {
    let input = transaction.inputs[input_to_sign];
    let left_part = input.script_sig_size.offset;

    // The transaction should contain empty script_sigs
    assert(input.script_sig.size == 0);
    
    let mut data = [0; TRANSACTION_SIZE - 1 + SCRIPT_PUB_KEY_SIZE + 4];

    for i in 0..TRANSACTION_SIZE {
        if i < left_part {
            data[i] = transaction.data[i];
        } else if i == left_part {
            // continue
        } else {
            data[i - 1 + SCRIPT_PUB_KEY_SIZE] = transaction.data[i];
        }
    }
    for i in 0..SCRIPT_PUB_KEY_SIZE {
        data[left_part + i] = script_pub_key[i];
    }

    data[TRANSACTION_SIZE - 1 + SCRIPT_PUB_KEY_SIZE + 0] = hash_type;
    data[TRANSACTION_SIZE - 1 + SCRIPT_PUB_KEY_SIZE + 1] = 0x00;
    data[TRANSACTION_SIZE - 1 + SCRIPT_PUB_KEY_SIZE + 2] = 0x00;
    data[TRANSACTION_SIZE - 1 + SCRIPT_PUB_KEY_SIZE + 3] = 0x00;

    data
}


fn serialize_sighash_all_legacy_transaction<
    let TRANSACTION_SIZE: u32,
    let INPUT_COUNT: u32,
    let OUTPUT_COUNT: u32,
    let MAX_WITNESS_STACK_SIZE: u32,
    let SCRIPT_PUB_KEY_SIZE: u32,
> (
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, OUTPUT_COUNT, MAX_WITNESS_STACK_SIZE>,
    input_to_sign: u32,
    // script_pub_key should contain script_pub_key_size along with the script_pub_key
    script_pub_key: [u8; SCRIPT_PUB_KEY_SIZE],
    hash_type: u8,
) -> [u8; 32] {
    assert(transaction.is_segwit() == false);
    assert(input_to_sign < INPUT_COUNT);

    let transaction_data = insert_script_pub_key_and_hash_type(transaction, input_to_sign, script_pub_key, hash_type);

    let hashed_transaction = sha256::digest(sha256::digest(transaction_data));

    hashed_transaction
}

#[test]
fn test_sign_legacy_transaction() {
    let string = "0100000001b7994a0db2f373a29227e1d90da883c6ce1cb0dd2d6812e4558041ebbbcfa54b0000000000ffffffff01983a0000000000001976a914b3e2819b6262e0b1f19fc7229d75677f347c91ac88ac00000000";
    let bytes = hex_to_bytes(string);
    let transaction = Transaction::<85, 1, 1, 1>::new(bytes, false);

    let script_pub_key = "1976a9144299ff317fcd12ef19047df66d72454691797bfc88ac";
    let script_pub_key_bytes = hex_to_bytes(script_pub_key);

    let sighash_all_transaction_bytes = serialize_sighash_all_legacy_transaction(transaction, 0, script_pub_key_bytes, 0x01);

    let sighash_all_transaction = bytes_to_hex_string(sighash_all_transaction_bytes);

    assert(sighash_all_transaction == "a6b4103f527dfe43dfbadf530c247bac8a98b7463c7c6ad38eed97021d18ffcb");
}
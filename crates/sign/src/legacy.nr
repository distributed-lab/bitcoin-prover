use crate::transaction::Transaction;

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
) -> [u8; TRANSACTION_SIZE - 1 + SCRIPT_PUB_KEY_SIZE + 1] {
    let input = transaction.inputs[input_to_sign];
    let left_part = input.script_sig_size.offset;
    let right_part = input.script_sig.offset + input.script_sig.size;

    // The transaction should contain empty script_sigs
    assert(left_part + 1 == right_part);
    
    let mut data = [0; TRANSACTION_SIZE - 1 + SCRIPT_PUB_KEY_SIZE + 1];

    for i in 0..TRANSACTION_SIZE {
        if i < left_part {
            data[i] = transaction.data[i];
        } else if i == left_part {
            // continue
        } else {
            data[i] = transaction.data[i - 1 + SCRIPT_PUB_KEY_SIZE];
        }
    }
    for i in 0..SCRIPT_PUB_KEY_SIZE {
        data[left_part + i] = script_pub_key[i];
    }
    data[TRANSACTION_SIZE - 1 + SCRIPT_PUB_KEY_SIZE] = hash_type;

    data
}


fn sign_legacy_transaction<
    let TRANSACTION_SIZE: u32,
    let INPUT_COUNT: u32,
    let OUTPUT_COUNT: u32,
    let MAX_WITNESS_STACK_SIZE: u32,
    let SCRIPT_PUB_KEY_SIZE: u32,
>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, OUTPUT_COUNT, MAX_WITNESS_STACK_SIZE>,
    input_to_sign: u32,
    script_pub_key: [u8; SCRIPT_PUB_KEY_SIZE],
    hash_type: u8
) {
    assert(transaction.is_segwit() == false);
    assert(input_to_sign < INPUT_COUNT);

    let transaction_data = insert_script_pub_key_and_hash_type(transaction, input_to_sign, script_pub_key, hash_type);

    let hashed_transaction = sha256::digest(sha256::digest(transaction_data));


}


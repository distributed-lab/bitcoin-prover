use crate::transaction::Transaction;

fn sign_legacy<
    let TRANSACTION_SIZE: u32,
    let INPUT_COUNT: u32,
    let OUTPUT_COUNT: u32,
    let MAX_WITNESS_STACK_SIZE: u32,
>(
    transaction: Transaction<TRANSACTION_SIZE, INPUT_COUNT, OUTPUT_COUNT, MAX_WITNESS_STACK_SIZE>,
) {
    assert(transaction.is_segwit() == false);

    
}
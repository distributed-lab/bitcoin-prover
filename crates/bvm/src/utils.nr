

pub(crate) fn split_raw_signature<let SIGNATURE_LEN: u32>(
    signature: [u8; SIGNATURE_LEN],
) -> ([u8; SIGNATURE_LEN - 1], u8) {
    let mut encoded_signature = [0; SIGNATURE_LEN - 1];
    let hash_type = signature[SIGNATURE_LEN - 1];
    for i in 0..SIGNATURE_LEN - 1 {
        encoded_signature[i] = signature[i];
    }
    (encoded_signature, hash_type)
}

pub(crate) fn empty_stack_array<let MAX_STACK_ELEMENT_SIZE: u32, let MAX_STACK_SIZE: u32>() -> [BoundedVec<u8, MAX_STACK_ELEMENT_SIZE>; MAX_STACK_SIZE] {
    [BoundedVec::new(); MAX_STACK_SIZE]
}
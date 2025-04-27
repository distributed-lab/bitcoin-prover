struct Block {
    version: u32,
    prev_block: str<64>,
    merkle_root: str<64>,
    timestamp: Field,
    bits: str<8>,
    nonce: u32
}

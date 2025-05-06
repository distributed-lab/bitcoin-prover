use super::convert::{bytes_to_hex_string, reverse_bytes, sha256_to_le_bytes, u32_to_le_bytes};

pub(crate) struct BlockHeader {
    pub version: u32,
    pub prev_block: str<64>,
    pub merkle_root: str<64>,
    pub timestamp: u32,
    pub bits: u32,
    pub nonce: u32,
}

impl BlockHeader {
    pub(crate) fn to_byte_array(self) -> [u8; 80] {
        let mut res = u32_to_le_bytes(self.version).as_slice();

        res = res.append(sha256_to_le_bytes(self.prev_block));

        res = res.append(sha256_to_le_bytes(self.merkle_root));

        res = res.append(u32_to_le_bytes(self.timestamp));

        res = res.append(u32_to_le_bytes(self.bits));

        res = res.append(u32_to_le_bytes(self.nonce));

        res.as_array()
    }
}

pub(crate) fn get_block_hash(value: BlockHeader) -> str<64> {
    bytes_to_hex_string(
        reverse_bytes(sha256::digest(sha256::digest(value.to_byte_array()))),
    )
}

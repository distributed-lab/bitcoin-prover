use convert::convert::{
    bytes_to_hex, hex_to_bytes, reverse_bytes, sha256_to_le_bytes, u32_to_le_bytes,
};

pub struct BlockHeader {
    pub version: u32,
    pub prev_block: str<64>,
    pub merkle_root: str<64>,
    pub timestamp: u32,
    pub bits: u32,
    pub nonce: u32,
}

impl BlockHeader {
    pub fn to_byte_array(self) -> [u8; 80] {
        let mut res = u32_to_le_bytes(self.version).as_slice();

        res = res.append(sha256_to_le_bytes(self.prev_block));

        res = res.append(sha256_to_le_bytes(self.merkle_root));

        res = res.append(u32_to_le_bytes(self.timestamp));

        res = res.append(u32_to_le_bytes(self.bits));

        res = res.append(u32_to_le_bytes(self.nonce));

        res.as_array()
    }
}

pub fn get_block_hash(value: BlockHeader) -> str<64> {
    bytes_to_hex(
        reverse_bytes(sha256::digest(sha256::digest(value.to_byte_array()))),
    )
}

pub fn get_merkle_branch_from_1024_blocks(blocks: [BlockHeader; 1024]) -> [u8; 32] {
    let mut arr_512 = [[0; 32]; 512];
    for i in 0..512 {
        arr_512[i] = sha256::digest(hex_to_bytes(get_block_hash(blocks[2 * i]))
            .as_slice()
            .append(hex_to_bytes(get_block_hash(blocks[2 * i + 1])))
            .as_array::<64>());
    }

    let mut arr_256 = [[0; 32]; 256];
    for i in 0..256 {
        arr_256[i] = sha256::digest(arr_512[2 * i]
            .as_slice()
            .append(arr_512[2 * i + 1])
            .as_array::<64>());
    }

    let mut arr_128 = [[0; 32]; 128];
    for i in 0..128 {
        arr_128[i] = sha256::digest(arr_256[2 * i]
            .as_slice()
            .append(arr_256[2 * i + 1])
            .as_array::<64>());
    }

    let mut arr_64 = [[0; 32]; 64];
    for i in 0..64 {
        arr_64[i] = sha256::digest(arr_128[2 * i]
            .as_slice()
            .append(arr_128[2 * i + 1])
            .as_array::<64>());
    }

    let mut arr_32 = [[0; 32]; 32];
    for i in 0..32 {
        arr_32[i] = sha256::digest(arr_64[2 * i]
            .as_slice()
            .append(arr_64[2 * i + 1])
            .as_array::<64>());
    }

    let mut arr_16 = [[0; 32]; 16];
    for i in 0..16 {
        arr_16[i] = sha256::digest(arr_32[2 * i]
            .as_slice()
            .append(arr_32[2 * i + 1])
            .as_array::<64>());
    }

    let mut arr_8 = [[0; 32]; 8];
    for i in 0..8 {
        arr_8[i] = sha256::digest(arr_16[2 * i].as_slice().append(arr_16[2 * i + 1]).as_array::<64>());
    }

    let mut arr_4 = [[0; 32]; 4];
    for i in 0..4 {
        arr_4[i] = sha256::digest(arr_8[2 * i].as_slice().append(arr_8[2 * i + 1]).as_array::<64>());
    }

    let mut arr_2 = [[0; 32]; 2];
    for i in 0..2 {
        arr_2[i] = sha256::digest(arr_4[2 * i].as_slice().append(arr_4[2 * i + 1]).as_array::<64>());
    }

    sha256::digest(arr_2[0].as_slice().append(arr_2[1]).as_array::<64>())
}

pub fn calc_merkle_state<let SIZE: u32>(
    mut prev_merkle_state: [[u8; 32]; SIZE],
    mut new_branch: [u8; 32],
) -> [[u8; 32]; SIZE] {
    let mut change = true;
    for i in 0..SIZE {
        if change {
            if prev_merkle_state[i].all(|e| e == 0) {
                prev_merkle_state[i] = new_branch;
                change = false;
            } else {
                new_branch = sha256::digest(prev_merkle_state[i]
                    .as_slice()
                    .append(new_branch)
                    .as_array::<64>());
                prev_merkle_state[i] = [0; 32];
            }
        }
    }

    assert(!prev_merkle_state[SIZE - 1].all(|e| e == 0), "Incorrect merkle state len");

    prev_merkle_state
}

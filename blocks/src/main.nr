use sha256;

fn u32_to_le_bytes(value: u32) -> [u8; 4] {
    let mut res = [0; 4];
    for i in 0..4 {
        res[i] = (value >> (i * 8)) as u8;
    }

    res
}

fn sha256_to_le_bytes(value: str<64>) -> [u8; 32] {
    let mut res = [0; 32];
    let value = value.as_bytes();
    for i in 0..32 {
        res[31 - i] =
            (hex_symbol_to_byte(value[2 * i]) << 4) + hex_symbol_to_byte(value[2 * i + 1]);
    }

    res
}

fn bytes_to_hex_string(value: [u8; 32]) -> str<64> {
    let mut res = [0; 64];
    for i in 0..32 {
        res[2 * i] = byte_to_hex_symbol(value[i] >> 4);
        res[2 * i + 1] = byte_to_hex_symbol(value[i] & 0xf);
    }

    str<64>::from(res)
}

fn byte_to_hex_symbol(value: u8) -> u8 {
    if value <= 9 {
        value + 48
    } else {
        value + 87
    }
}

fn hex_symbol_to_byte(value: u8) -> u8 {
    if value < 58 {
        value - 48
    } else {
        value - 87
    }
}

fn reverse_bytes(bytes: [u8; 32]) -> [u8; 32] {
    let mut res = [0; 32];
    for i in 0..32 {
        res[i] = bytes[31 - i];
    }
    res
}

struct Block {
    version: u32,
    prev_block: str<64>,
    merkle_root: str<64>,
    timestamp: u32,
    bits: u32,
    nonce: u32,
}

impl Block {
    fn to_byte_array(self) -> [u8; 80] {
        let mut res = [0; 80];
        let mut count = 0;

        let vers = u32_to_le_bytes(self.version);
        for i in 0..4 {
            res[count] = vers[i];
            count += 1;
        }

        let prev = sha256_to_le_bytes(self.prev_block);
        for i in 0..32 {
            res[count] = prev[i];
            count += 1;
        }

        let merkle = sha256_to_le_bytes(self.merkle_root);
        for i in 0..32 {
            res[count] = merkle[i];
            count += 1;
        }

        let time = u32_to_le_bytes(self.timestamp);
        for i in 0..4 {
            res[count] = time[i];
            count += 1;
        }

        let bits = u32_to_le_bytes(self.bits);
        for i in 0..4 {
            res[count] = bits[i];
            count += 1;
        }

        let nonce = u32_to_le_bytes(self.nonce);
        for i in 0..4 {
            res[count] = nonce[i];
            count += 1;
        }

        res
    }
}

fn get_block_hash(value: Block) -> str<64> {
    bytes_to_hex_string(
        reverse_bytes(sha256::digest(sha256::digest(value.to_byte_array()))),
    )
}

fn main() {
    let block = Block {
        version: 1,
        prev_block: "00000000b873e79784647a6c82962c70d228557d24a747ea4d1b8bbe878e1206",
        merkle_root: "20222eb90f5895556926c112bb5aa0df4ab5abc3107e21a6950aec3b2e3541e2",
        timestamp: 1296688946,
        bits: 486604799,
        nonce: 875942400,
    };

    assert(
        get_block_hash(block) == "000000006c02c8ea6e4ff69651f7fcde348fb9d557a06e6957b65552002a7820",
    );
    println(get_block_hash(block));
}

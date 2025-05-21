pub(crate) fn u32_to_le_bytes(value: u32) -> [u8; 4] {
    let mut res = [0; 4];
    for i in 0..4 {
        res[i] = (value >> (i << 3)) as u8;
    }

    res
}

pub(crate) fn u32_to_be_bytes(value: u32) -> [u8; 4] {
    let mut res = [0; 4];
    for i in 0..4 {
        res[i] = (value >> ((3 - i) << 3)) as u8;
    }

    res
}

pub(crate) fn sha256_to_le_bytes(value: str<64>) -> [u8; 32] {
    let mut res = [0; 32];
    let value = value.as_bytes();
    for i in 0..32 {
        res[31 - i] =
            (hex_symbol_to_byte(value[i << 1]) << 4) + hex_symbol_to_byte(value[(i << 1) + 1]);
    }

    res
}

pub(crate) fn bytes_to_hex_string(value: [u8; 32]) -> str<64> {
    let mut res = [0; 64];
    for i in 0..32 {
        res[i << 1] = byte_to_hex_symbol(value[i] >> 4);
        res[(i << 1) + 1] = byte_to_hex_symbol(value[i] & 0xf);
    }

    res.as_str_unchecked()
}

pub(crate) fn byte_to_hex_symbol(value: u8) -> u8 {
    if value <= 9 {
        value + 48
    } else {
        value + 87
    }
}

pub(crate) fn hex_symbol_to_byte(value: u8) -> u8 {
    if value < 58 {
        value - 48
    } else {
        value - 87
    }
}

pub(crate) fn reverse_bytes(bytes: [u8; 32]) -> [u8; 32] {
    let mut res = [0; 32];
    for i in 0..32 {
        res[i] = bytes[31 - i];
    }
    res
}

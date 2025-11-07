pub fn deobfuscate(data: &[u8], obfuscation_key: &[u8]) -> Vec<u8> {
    if obfuscation_key.is_empty() {
        return data.to_vec();
    }

    data.iter()
        .enumerate()
        .map(|(i, &byte)| byte ^ obfuscation_key[i % obfuscation_key.len()])
        .collect()
}

pub fn read_var_int_u64(data: &[u8]) -> Option<(u64, usize)> {
    let mut result: u64 = 0;
    let mut consumed = 0;

    for byte in data {
        consumed += 1;

        if result > (u64::MAX >> 7) {
            return None;
        }

        result = (result << 7) | u64::from(byte & 0x7F);
        if byte & 0x80 != 0x00 {
            if result == u64::MAX {
                return None;
            }

            result += 1;
        } else {
            return Some((result, consumed));
        }
    }

    None
}

pub fn read_var_int_u32(data: &[u8]) -> Option<(u32, usize)> {
    let mut result: u32 = 0;
    let mut consumed = 0;

    for byte in data {
        consumed += 1;

        if result > (u32::MAX >> 7) {
            return None;
        }

        result = (result << 7) | u32::from(byte & 0x7F);
        if byte & 0x80 != 0x00 {
            if result == u32::MAX {
                return None;
            }

            result += 1;
        } else {
            return Some((result, consumed));
        }
    }

    None
}

pub fn decompress_amount(x: u64) -> u64 {
    if x == 0 {
        return 0;
    }

    let mut x = x - 1;
    let e = (x % 10) as u32;
    x /= 10;

    if e < 9 {
        let d = (x % 9) + 1;
        let n = x / 9;
        let n_full = n * 10 + d;

        n_full * 10u64.pow(e)
    } else {
        (x + 1) * 10u64.pow(9)
    }
}

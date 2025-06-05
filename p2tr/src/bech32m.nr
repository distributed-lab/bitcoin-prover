use super::merkle_root::hex_to_bytes;

global bech32m: [u8; 32] = "qpzry9x8gf2tvdw0s3jn54khce6mua7l".as_bytes();

pub(crate) fn get_address(value: [u8; 32]) -> str<62> {
    let mut res = [0; 0].as_slice();

    let data = bytes_to_bits(value).as_slice().append([0, 0, 0, 0]);

    let mut nums = [0; 0].as_slice();
    for i in 0..52 {
        nums = nums.push_back(bits_5_to_num([
            data[i * 5],
            data[i * 5 + 1],
            data[i * 5 + 2],
            data[i * 5 + 3],
            data[i * 5 + 4],
        ]));
    }

    res = res.append(nums);

    nums = bech32m_hrp_expand("bc").as_slice().push_back(1).append(nums).append([0, 0, 0, 0, 0, 0]);

    let mut chk: u32 = 1;

    let generator: [u32; 5] = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3];

    for i in 0..64 {
        let top = chk >> 25;
        chk = ((chk & 0x1FFFFFF) << 5) ^ nums[i] as u32;
        for j in 0..5 {
            if (top >> j) as u1 == 1 {
                chk ^= generator[j];
            }
        }
    }

    chk = chk ^ 0x2bc830a3;

    for i in 0..6 {
        res = res.push_back((chk >> (5 * (5 - i)) & 0x1f) as u8);
    }

    for i in 0..58 {
        res[i] = bech32m[res[i]];
    }

    "bc1p".as_bytes().as_slice().append(res).as_array().as_str_unchecked()
}

fn bech32m_hrp_expand(value: str<2>) -> [u8; 5] {
    let b = value.as_bytes();
    [b[0] >> 5, b[1] >> 5, 0, b[0] % 32, b[1] % 32]
}

fn bytes_to_bits<let N: u32>(value: [u8; N]) -> [u1; N * 8] {
    let mut res = [0; 0].as_slice();
    for i in 0..N {
        for j in 0..8 {
            res = res.push_back((value[i] >> (7 - j)) as u1);
        }
    }

    res.as_array()
}

fn bits_5_to_num(value: [u1]) -> u8 {
    let mut res = 0;

    for i in 0..5 {
        res += (value[i] as u8 << (4 - i));
    }

    res
}

#[test]
fn bech32m_hrp_expand_test() {
    assert(bech32m_hrp_expand("bc") == [3, 3, 0, 2, 3]);
}

#[test]
fn bech32m_test() {
    // 3e2a04301a44f3e709011a24112deca591412a97d9c673acb15ceac031779f42
    assert(
        get_address([
            0x3e, 0x2a, 0x04, 0x30, 0x1a, 0x44, 0xf3, 0xe7, 0x09, 0x01, 0x1a, 0x24, 0x11, 0x2d,
            0xec, 0xa5, 0x91, 0x41, 0x2a, 0x97, 0xd9, 0xc6, 0x73, 0xac, 0xb1, 0x5c, 0xea, 0xc0,
            0x31, 0x77, 0x9f, 0x42,
        ])
            == "bc1p8c4qgvq6gne7wzgprgjpzt0v5kg5z25hm8r88t93tn4vqvthnapqhffa0r",
    );
}

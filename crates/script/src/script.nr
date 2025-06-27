use utils::convert::hex_to_bytes;

pub fn check_p2pkh_template<let LEN: u32>(script_pub_key: [u8; LEN]) -> bool {
    assert(LEN == 26);
    let mut check = true;

    // p2pkh always has 25 bytes len
    if script_pub_key[0] != 25 {
        check = false;
    }

    if script_pub_key[1] != 118 {
        check = false;
    }

    if script_pub_key[2] != 169 {
        check = false;
    }

    if script_pub_key[3] != 20 {
        check = false;
    }

    if script_pub_key[24] != 136 {
        check = false;
    }

    if script_pub_key[25] != 172 {
        check = false;
    }

    check
}

pub fn check_p2wpkh_template<let LEN: u32>(script: str<LEN>) -> bool {
    assert(LEN == 44);
    let script = hex_to_bytes(script);
    let mut check = true;

    if script[0] != 0 {
        check = false;
    }

    if script[1] != 20 {
        check = false;
    }

    check
}

#[test]
fn templates_test() {
    let script = "76a91455ae51684c43435da751ac8d2173b2652eb6410588ac";
    assert(check_p2pkh_template(hex_to_bytes(script)));

    let script = "0014841b80d2cc75f5345c482af96294d04fdd66b2b7";
    assert(check_p2wpkh_template(script));
}

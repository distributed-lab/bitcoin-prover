use super::base58::script_to_bytes;

// All opcodes from 0 to 186 except [error] exists.
global error: [u8; 15] =
    [126, 127, 128, 129, 131, 132, 133, 134, 141, 142, 149, 150, 151, 152, 153];

pub fn check_opcodes<let LEN: u32>(script: [u8; LEN]) -> bool {
    let mut res = true;
    let mut ignore_to = 0;
    let mut size = 0;

    for i in 0..LEN {
        if ignore_to <= i {
            if (script[i] > 186) | error.any(|code| code == script[i]) {
                res = false;
            }

            if (script[i] > 0) & (script[i] < 76) {
                ignore_to = i + script[i] as u32 + 1;
            }

            if script[i] == 76 {
                ignore_to = i + script[i + 1] as u32 + 2;
            }

            if script[i] == 77 {
                size = script[i + 1] as u32 + script[i + 2] as u32 * (2.pow_32(8) as Field) as u32;
                ignore_to = i + size as u32 + 3;
            }

            if script[i] == 78 {
                size = script[i + 1] as u32
                    + script[i + 2] as u32 * (2.pow_32(8) as Field) as u32
                    + script[i + 3] as u32 * (2.pow_32(16) as Field) as u32
                    + script[i + 4] as u32 * (2.pow_32(24) as Field) as u32;

                ignore_to = i + size as u32 + 5;
            }
        }
    }

    res
}

#[test]
fn push_bytes_test() {
    // OP_PUSHDATA1
    // 20 (32 bytes)
    // aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    // OP_PUSHDATA2
    // 2000 (32 bytes)
    // aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    // OP_PUSHDATA4
    // 200000 (32 bytes)
    // aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    let script = "4c20aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa4d2000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa4e20000000aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

    assert(check_opcodes(script_to_bytes(script)));
}

#[test]
fn mulsig_test() {
    // OP_2
    // OP_PUSHBYTES_65
    // 04f3d35132084eb1b99b6506178c20adb42d26296012e452e392689bdb6553db33ba24b900000892805de1646821c7b0fb50b3d879c26e2b493b7041e6215356a0
    // OP_PUSHBYTES_65
    // 04ab4ecc9e8ea2da0562af25bcaede00c4d5a00db60edc17672376decf0a35a34fdc9f1ffad1fb74fd7b1b198b9231c25df88e0769bec49975649b4b3f40adafb0
    // OP_PUSHBYTES_65
    // 04f7149f270717c00f6cc09b9ce3c22791c4aab1af40a5107aacca85b6f644cc0d84459e308f998d801b8d9d355f8ec33b0e41866841e2870754cf667a9821703d
    // OP_3
    // OP_CHECKMULTISIG
    let script = "524104f3d35132084eb1b99b6506178c20adb42d26296012e452e392689bdb6553db33ba24b900000892805de1646821c7b0fb50b3d879c26e2b493b7041e6215356a04104ab4ecc9e8ea2da0562af25bcaede00c4d5a00db60edc17672376decf0a35a34fdc9f1ffad1fb74fd7b1b198b9231c25df88e0769bec49975649b4b3f40adafb04104f7149f270717c00f6cc09b9ce3c22791c4aab1af40a5107aacca85b6f644cc0d84459e308f998d801b8d9d355f8ec33b0e41866841e2870754cf667a9821703d53ae";

    assert(check_opcodes(script_to_bytes(script)));
}

#[test(should_fail)]
fn using_disabled_OP_test() {
    // 7e - disabled OP code
    let script = "7eaaabbbcc";
    assert(check_opcodes(script_to_bytes(script)));
}

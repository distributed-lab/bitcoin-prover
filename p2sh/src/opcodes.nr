// All opcodes from 0 to 186 except [error] exists.
global error: [u8; 15] =
    [126, 127, 128, 129, 131, 132, 133, 134, 141, 142, 149, 150, 151, 152, 153];

pub(crate) fn check_opcodes<let LEN: u32>(script: [u8; LEN]) -> bool {
    let mut res = true;
    let mut ignore_to = 0;
    let mut size_bytes = 0;
    let mut size = 0;
    let mut size_to = 0;

    for i in 0..LEN {
        if ignore_to > i {
            //
        } else if size_to > i {
            size +=
                script[i] as u32 * (2.pow_32(((size_bytes - (size_to - i)) * 8) as Field)) as u32;
            if size_to - 1 == i {
                ignore_to = i + size + 1;
                size = 0;
            }
        } else {
            if (script[i] > 186) | error.any(|code| code == script[i]) {
                res = false;
            }

            if (script[i] > 0) & (script[i] < 76) {
                ignore_to = i + script[i] as u32 + 1;
            }

            if (script[i] == 76) | (script[i] == 77) {
                size_to = i + script[i] as u32 - 75 + 1;
                size_bytes = script[i] as u32 - 75;
            }

            if script[i] == 78 {
                size_to = i + 4 + 1;
                size_bytes = 4;
            }
        }
    }

    res
}

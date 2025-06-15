use p2sh_lib::script::{check_opcodes, check_script};
use utils::convert::hex_to_bytes;

global ADDR_LEN: u32 = 34;

fn main(script: str<402>, addr: pub str<ADDR_LEN>) -> pub bool {
    check_script(script, addr) | check_opcodes(hex_to_bytes(script))
}

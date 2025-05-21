use base58::{check_script, script_to_bytes};
use opcodes::check_opcodes;

mod base58;
mod opcodes;

global ADDR_LEN: u32 = 34;

fn main(script: str<402>, addr: pub str<ADDR_LEN>) -> pub bool {
    check_script(script, addr) | check_opcodes(script_to_bytes(script))
}

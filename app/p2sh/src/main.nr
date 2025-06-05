use p2sh_lib::{check_script, check_opcodes, script_to_bytes};
                   
global ADDR_LEN: u32 = 34;

fn main(script: str<402>, addr: pub str<ADDR_LEN>) -> pub bool {
    check_script(script, addr) | check_opcodes(script_to_bytes(script)) 
}
                   
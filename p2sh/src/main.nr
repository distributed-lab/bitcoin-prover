use base58::check_script;

mod base58;

global ADDR_LEN: u32 = 34;

fn main(script: str<142>, addr: pub str<ADDR_LEN>) -> pub bool {
    check_script(script, addr)
}

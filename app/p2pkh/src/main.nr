use bvm::stack::Stack;
use script::script::check_p2pkh_template;
use sign::transaction::Transaction;
use utils::convert::{hex_to_bytes, le_bytes_to_u32};

global CUR_TX_LEN: u32 = 201;
global PREV_TX_LEN: u32 = 126;
global SIG_LEN: u32 = 144;
global PK_LEN: u32 = 130;

fn main(
    cur_tx_data: [u8; CUR_TX_LEN],
    prev_tx_data: [u8; PREV_TX_LEN],
    signature: str<SIG_LEN>,
    pub_key: str<PK_LEN>,
    input_to_sign: pub u32,
) -> pub bool {
    let mut res = true;

    let cur_tx = Transaction::<CUR_TX_LEN, 3, 124, 2, 69, 0, 0>::new(cur_tx_data, false);
    let prev_tx = Transaction::<PREV_TX_LEN, 2, 83, 1, 35, 0, 0>::new(prev_tx_data, false);
    let mut stack = Stack::<100, 10, CUR_TX_LEN, 3, 124, 2, 69, 0, 0>::new(cur_tx);
    let mut script_pub_key = [0; 26];

    let vout_pos = cur_tx.inputs[input_to_sign].vout.offset;
    let mut vout_bytes = [0; 4];

    for i in 0..4 {
        vout_bytes[i] = cur_tx.data[vout_pos + i];
    }

    let vout = le_bytes_to_u32(vout_bytes);
    let script_pub_key_pos = prev_tx.outputs[vout].script_pub_key.offset;

    script_pub_key[0] = 25;
    for i in 0..25 {
        script_pub_key[i + 1] = prev_tx.data[script_pub_key_pos + i];
    }

    assert(check_p2pkh_template(script_pub_key));

    stack.op_pushbytes(hex_to_bytes(signature));
    stack.op_pushbytes(hex_to_bytes(pub_key));
    stack.op_dup();
    stack.op_hash160::<PK_LEN / 2>();

    let mut hash_pub_key = [0; 20];
    for i in 0..20 {
        hash_pub_key[i] = script_pub_key[i + 4];
    }

    stack.op_pushbytes(hash_pub_key);
    stack.op_equal();

    if !stack.verify() {
        println("Failed pk hash");
        res = false;
    }

    if !stack.op_checksig_sighash_all::<SIG_LEN / 2, 26, PK_LEN / 2>(input_to_sign, script_pub_key) {
        println("Failed signature");
        res = false;
    }

    res
}

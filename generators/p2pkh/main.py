import json
from typing import Dict
import tx
from typing import List

def get_config(path: str = "./generators/p2pkh/config.json") -> Dict:
    with open(path, "r") as f:
        return json.load(f)

def main():
    config = get_config()

    curTx = tx.get_ready_tx(config["cur_tx"])

    prevTx = tx.get_ready_tx(config["prev_tx"])

    with open(config["file_path"] + "/src/main.nr", "w") as file:
        file.write(f"""use sign::transaction::Transaction;
use bvm::stack::Stack;
use utils::convert::{{le_bytes_to_u32, hex_to_bytes}};
use script::script::check_p2pkh_template;

global CUR_TX_LEN: u32 = {len(curTx.txData)};
global PREV_TX_LEN: u32 = {len(prevTx.txData)};
global SIG_LEN: u32 = {len(config['signature'])};
global PK_LEN: u32 = {len(config['pub_key'])};

fn main(cur_tx_data: [u8; CUR_TX_LEN], prev_tx_data: [u8; PREV_TX_LEN], signature: str<SIG_LEN>, pub_key: str<PK_LEN>, input_to_sign: pub u32) -> pub bool {{
    let mut res = true;

    let cur_tx = Transaction::<CUR_TX_LEN, {curTx.inputCount}, {curTx.inputSize}, {curTx.outputCount}, {curTx.outputSize}, {curTx.maxWitnessStackSize}, {curTx.witnessSize}>::new(cur_tx_data, false);
    let prev_tx = Transaction::<PREV_TX_LEN, {prevTx.inputCount}, {prevTx.inputSize}, {prevTx.outputCount}, {prevTx.outputSize}, {prevTx.maxWitnessStackSize}, {prevTx.witnessSize}>::new(prev_tx_data, false);
    let mut stack = Stack::<100, 10, CUR_TX_LEN, {curTx.inputCount}, {curTx.inputSize}, {curTx.outputCount}, {curTx.outputSize}, {curTx.maxWitnessStackSize}, {curTx.witnessSize}>::new(cur_tx);
    let mut script_pub_key = [0; 26];

    let vout_pos = cur_tx.inputs[input_to_sign].vout.offset;
    let mut vout_bytes = [0; 4];

    for i in 0..4 {{
        vout_bytes[i] = cur_tx.data[vout_pos + i];
    }}

    let vout = le_bytes_to_u32(vout_bytes);
    let script_pub_key_pos = prev_tx.outputs[vout].script_pub_key.offset;

    script_pub_key[0] = 25;
    for i in 0..25 {{
        script_pub_key[i + 1] = prev_tx.data[script_pub_key_pos + i];
    }}

    assert(check_p2pkh_template(script_pub_key));

    stack.op_pushbytes(hex_to_bytes(signature));
    stack.op_pushbytes(hex_to_bytes(pub_key));
    stack.op_dup();
    stack.op_hash160::<PK_LEN / 2>();

    let mut hash_pub_key = [0; 20];
    for i in 0..20 {{
        hash_pub_key[i] = script_pub_key[i + 4];
    }}

    stack.op_pushbytes(hash_pub_key);
    stack.op_equal();
    
    if !stack.verify() {{
        println("Failed pk hash");
        res = false;
    }}
                   
    if !stack.op_checksig_sighash_all::<SIG_LEN / 2, 26, PK_LEN / 2>(input_to_sign, script_pub_key) {{
        println("Failed signature");
        res = false;
    }}

    res
}}
""")
        
    with open(config["file_path"] + "/Prover.toml", "w") as file:
        file.write(f'''cur_tx_data = {proverify(curTx.txData)}
prev_tx_data = {proverify(prevTx.txData)}
signature = "{config["signature"]}"
pub_key = "{config["pub_key"]}"
input_to_sign = "{config["input_to_sign"]}"
''')
        
def proverify(val: List[int]) -> str:
    return '[' + ', '.join('"' + str(x) + '"' for x in val) + ']'

if __name__ == "__main__":
    main()
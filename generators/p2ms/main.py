import json
from typing import Dict
from generators.utils.tx import Transaction
from generators.utils.script import Script
from generators.utils.opcodes_gen import generate

def get_config(path: str = "./generators/p2ms/config.json") -> Dict:
    with open(path, "r") as f:
        return json.load(f)

def main():
    print("Spending type: p2ms")

    config = get_config()

    curTx = Transaction(config["cur_tx"])
    curTx.cut_script_sigs()

    vout = curTx.inputs[config["input_to_sign"]].vout

    prevTx = Transaction(config["prev_tx"])
    prevTx.cut_script_sigs()

    script_pub_key = prevTx.outputs[vout].script_pub_key
    script_pub_key_size = prevTx.outputs[vout].script_pub_key_size

    script = Script(config["script_sig"] + bytearray(script_pub_key).hex(), curTx, config["input_to_sign"])
    generate(script.sizes)

    with open(config["file_path"] + "/src/globals.nr.template", "r") as file:
        templateOpcodes = file.read()

    CUR_TX_INP_COUNT_LEN = curTx._get_compact_size_size(curTx.input_count)
    CUR_TX_INP_SIZE = sum(curTx._get_input_size(inp) for inp in curTx.inputs) + CUR_TX_INP_COUNT_LEN
    CUR_TX_OUT_COUNT_LEN = curTx._get_compact_size_size(curTx.output_count)
    CUR_TX_OUT_SIZE = sum(curTx._get_output_size(out) for out in curTx.outputs) + CUR_TX_OUT_COUNT_LEN

    PREV_TX_INP_COUNT_LEN = prevTx._get_compact_size_size(prevTx.input_count)
    PREV_TX_INP_SIZE = sum(prevTx._get_input_size(inp) for inp in prevTx.inputs) + PREV_TX_INP_COUNT_LEN
    PREV_TX_OUT_COUNT_LEN = prevTx._get_compact_size_size(prevTx.output_count)
    PREV_TX_OUT_SIZE = sum(prevTx._get_output_size(out) for out in prevTx.outputs) + PREV_TX_OUT_COUNT_LEN

    INPUT_TO_SIGN = config["input_to_sign"]

    opcodesFile = templateOpcodes.format(
        curTx=curTx, 
        prevTx=prevTx,
        CUR_TX_INP_COUNT_LEN=CUR_TX_INP_COUNT_LEN,
        CUR_TX_INP_SIZE=CUR_TX_INP_SIZE,
        CUR_TX_OUT_COUNT_LEN=CUR_TX_OUT_COUNT_LEN,
        CUR_TX_OUT_SIZE=CUR_TX_OUT_SIZE,
        PREV_TX_INP_COUNT_LEN=PREV_TX_INP_COUNT_LEN,
        PREV_TX_INP_SIZE=PREV_TX_INP_SIZE,
        PREV_TX_OUT_COUNT_LEN=PREV_TX_OUT_COUNT_LEN,
        PREV_TX_OUT_SIZE=PREV_TX_OUT_SIZE,
        opcodesAmount=script.opcodes,
        curTxLen=curTx._get_transaction_size() * 2, 
        prevTxLen=prevTx._get_transaction_size() * 2, 
        signLen=len(config['script_sig']),
        scriptPubKeyLen=len(script_pub_key),
        scriptPubKeyLenLen=curTx._get_compact_size_size(script_pub_key_size),
        stackSize=script.require_stack_size,
        maxStackElementSize=script.max_element_size,
        nOutputSize=curTx._get_output_size(curTx.outputs[INPUT_TO_SIGN]) if len(curTx.outputs) > INPUT_TO_SIGN else 0,
        inputToSign=INPUT_TO_SIGN,
        inputToSignLen=curTx._get_compact_size_size(INPUT_TO_SIGN),
        nInputSize=curTx._get_input_size(curTx.inputs[INPUT_TO_SIGN]),
    )

    with open(config["file_path"] + "/src/globals.nr", "w") as file:
        file.write(opcodesFile)

    with open(config["file_path"] + "/Prover.toml.template", "r") as file:
        templateProver = file.read()

    curTxData = curTx.to_hex()
    prevTxData = prevTx.to_hex()
        
    proverFile = templateProver.format(
        curTxData=curTxData,
        prevTxData=prevTxData,
        script_sig=config["script_sig"],
        input_to_sign=INPUT_TO_SIGN
    )

    with open(config["file_path"] + "/Prover.toml", "w") as file:
        file.write(proverFile)

if __name__ == "__main__":
    main()
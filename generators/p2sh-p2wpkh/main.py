import json
from typing import Dict
from generators.utils.tx import Transaction
from generators.utils.script import Script
from generators.utils.opcodes_gen import generate

def get_config(path: str = "./generators/p2sh-p2wpkh/config.json") -> Dict:
    with open(path, "r") as f:
        return json.load(f)

def main():
    print("Spending type: p2sh-p2wpkh")
    config = get_config()

    curTx = Transaction(config["cur_tx"])
    curTx.cut_script_sigs()

    vout = curTx.inputs[config["input_to_sign"]].vout

    prevTx = Transaction(config["prev_tx"])
    prevTx.cut_script_sigs()

    CUR_TX_INP_COUNT_LEN = curTx._get_compact_size_size(curTx.input_count)
    CUR_TX_INP_SIZE = sum(curTx._get_input_size(inp) for inp in curTx.inputs) + CUR_TX_INP_COUNT_LEN
    CUR_TX_OUT_COUNT_LEN = curTx._get_compact_size_size(curTx.output_count)
    CUR_TX_OUT_SIZE = sum(curTx._get_output_size(out) for out in curTx.outputs) + CUR_TX_OUT_COUNT_LEN
    CUR_TX_MAX_WITNESS_STACK_SIZE = 2
    CUR_TX_WITNESS_SIZE = sum(curTx._get_witness_size(wit) for wit in curTx.witness)

    PREV_TX_INP_COUNT_LEN = prevTx._get_compact_size_size(prevTx.input_count)
    PREV_TX_INP_SIZE = sum(prevTx._get_input_size(inp) for inp in prevTx.inputs) + PREV_TX_INP_COUNT_LEN
    PREV_TX_OUT_COUNT_LEN = prevTx._get_compact_size_size(prevTx.output_count)
    PREV_TX_OUT_SIZE = sum(prevTx._get_output_size(out) for out in prevTx.outputs) + PREV_TX_OUT_COUNT_LEN
    PREV_TX_MAX_WITNESS_STACK_SIZE = 2
    PREV_TX_WITNESS_SIZE = 0 if prevTx.witness == None else sum(prevTx._get_witness_size(wit) for wit in prevTx.witness)

    INPUT_TO_SIGN = config["input_to_sign"]

    script_pub_key = prevTx.outputs[vout].script_pub_key
    script_pub_key_size = prevTx.outputs[vout].script_pub_key_size

    script_sig = config["script_sig"]
    witness = curTx.witness_to_hex_script(INPUT_TO_SIGN)

    script = Script(script_sig + bytearray(script_pub_key).hex(), curTx, config["input_to_sign"])
    sizes = script.sizes

    rds = bytearray.fromhex(script.script_elements[-4])
    rds.pop(0)
    full_rds = [118, 169]
    full_rds.extend(list(rds))
    full_rds.extend([136, 172])
    rds = bytes(full_rds).hex()

    redeem_script = Script(witness + rds, curTx, config["input_to_sign"], [])
    sizes = sizes | redeem_script.sizes
    generate(sizes)

    require_stack_size = max(script.require_stack_size, redeem_script.require_stack_size)
    max_element_size = max(script.max_element_size, redeem_script.max_element_size)

    with open(config["file_path"] + "/src/globals.nr.template", "r") as file:
        templateOpcodes = file.read()

    signature = curTx.witness[INPUT_TO_SIGN].stack_items[0].item
    pub_key = curTx.witness[INPUT_TO_SIGN].stack_items[1].item

    opcodesFile = templateOpcodes.format(
        curTx=curTx, 
        prevTx=prevTx,
        signatureLen=len(signature),
        pkLen=len(pub_key),
        CUR_TX_INP_COUNT_LEN=CUR_TX_INP_COUNT_LEN,
        CUR_TX_INP_SIZE=CUR_TX_INP_SIZE,
        CUR_TX_OUT_COUNT_LEN=CUR_TX_OUT_COUNT_LEN,
        CUR_TX_OUT_SIZE=CUR_TX_OUT_SIZE,
        CUR_TX_MAX_WITNESS_STACK_SIZE=CUR_TX_MAX_WITNESS_STACK_SIZE,
        CUR_TX_WITNESS_SIZE=CUR_TX_WITNESS_SIZE,
        PREV_TX_INP_COUNT_LEN=PREV_TX_INP_COUNT_LEN,
        PREV_TX_INP_SIZE=PREV_TX_INP_SIZE,
        PREV_TX_OUT_COUNT_LEN=PREV_TX_OUT_COUNT_LEN,
        PREV_TX_OUT_SIZE=PREV_TX_OUT_SIZE,
        PREV_TX_MAX_WITNESS_STACK_SIZE=PREV_TX_MAX_WITNESS_STACK_SIZE,
        PREV_TX_WITNESS_SIZE=PREV_TX_WITNESS_SIZE,
        PREV_IS_GEGWIT=str(PREV_TX_WITNESS_SIZE != 0).lower(),
        curTxLen=curTx._get_transaction_size() * 2, 
        prevTxLen=prevTx._get_transaction_size() * 2, 
        signLen=len(script_sig),
        scriptPubKeyLen=len(script_pub_key),
        scriptPubKeyLenLen=curTx._get_compact_size_size(script_pub_key_size),
        redeemScriptLen=redeem_script.script_len_codeseparator,
        stackSize=require_stack_size,
        maxStackElementSize=max_element_size,
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
        script_sig=script_sig,
        signature=signature,
        pub_key=pub_key,
        input_to_sign=INPUT_TO_SIGN
    )

    with open(config["file_path"] + "/Prover.toml", "w") as file:
        file.write(proverFile)

if __name__ == "__main__":
    main()
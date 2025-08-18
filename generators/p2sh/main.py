import json
from typing import Dict
from generators.utils.tx import Transaction
from generators.utils.script import Script
from generators.utils.opcodes_gen import generate

def get_config(path: str = "./generators/p2sh/config.json") -> Dict:
    with open(path, "r") as f:
        return json.load(f)

def main():
    config = get_config()

    curTx = Transaction(config["cur_tx"])
    curTx.cut_script_sigs()

    vout = curTx.inputs[config["input_to_sign"]].vout

    prevTx = Transaction(config["prev_tx"])
    prevTx.cut_script_sigs()

    INPUT_TO_SIGN = config["input_to_sign"]

    CUR_TX_INP_COUNT_LEN = curTx._get_compact_size_size(curTx.input_count)
    CUR_TX_INP_SIZE = sum(curTx._get_input_size(inp) for inp in curTx.inputs) + CUR_TX_INP_COUNT_LEN
    CUR_TX_OUT_COUNT_LEN = curTx._get_compact_size_size(curTx.output_count)
    CUR_TX_OUT_SIZE = sum(curTx._get_output_size(out) for out in curTx.outputs) + CUR_TX_OUT_COUNT_LEN
    CUR_TX_MAX_WITNESS_STACK_SIZE = 0 if curTx.witness is None else max(len(w.stack_items) for w in curTx.witness)
    CUR_TX_WITNESS_SIZE = 0 if curTx.witness == None else sum(curTx._get_witness_size(wit) for wit in curTx.witness)

    PREV_TX_INP_COUNT_LEN = prevTx._get_compact_size_size(prevTx.input_count)
    PREV_TX_INP_SIZE = sum(prevTx._get_input_size(inp) for inp in prevTx.inputs) + PREV_TX_INP_COUNT_LEN
    PREV_TX_OUT_COUNT_LEN = prevTx._get_compact_size_size(prevTx.output_count)
    PREV_TX_OUT_SIZE = sum(prevTx._get_output_size(out) for out in prevTx.outputs) + PREV_TX_OUT_COUNT_LEN
    PREV_TX_MAX_WITNESS_STACK_SIZE = 0 if prevTx.witness is None else max(len(w.stack_items) for w in prevTx.witness)
    PREV_TX_WITNESS_SIZE = 0 if prevTx.witness == None else sum(prevTx._get_witness_size(wit) for wit in prevTx.witness)

    script_pub_key = prevTx.outputs[vout].script_pub_key
    script_pub_key_size = prevTx.outputs[vout].script_pub_key_size

    script_sig = config["script_sig"] if CUR_TX_WITNESS_SIZE == 0 else curTx.witness_to_hex_script(INPUT_TO_SIGN)

    if CUR_TX_WITNESS_SIZE != 0:
        print("Spending type: p2wsh")
        full_script_pub_key = [168, 32]
        full_script_pub_key.extend(script_pub_key[2:])
        full_script_pub_key.append(135)
        script_pub_key = full_script_pub_key
    else:
        print("Spending type: p2sh")

    script = Script(script_sig, curTx, config["input_to_sign"])
    sizes = script.sizes
    redeem_script = Script(script.script_elements[-1], curTx, config["input_to_sign"], script.script_elements[0:-1])
    sizes = sizes | redeem_script.sizes | Script(bytearray(script_pub_key).hex(), curTx, config["input_to_sign"], [script.script_elements[-1]]).sizes
    generate(sizes)

    require_stack_size = max(script.require_stack_size, redeem_script.require_stack_size)
    max_element_size = max(script.max_element_size, redeem_script.max_element_size)

    with open(config["file_path"] + "/src/globals.nr.template", "r") as file:
        templateOpcodes = file.read()

    opcodesFile = templateOpcodes.format(
        curTx=curTx, 
        prevTx=prevTx,
        CUR_TX_INP_COUNT_LEN=CUR_TX_INP_COUNT_LEN,
        CUR_TX_INP_SIZE=CUR_TX_INP_SIZE,
        CUR_TX_OUT_COUNT_LEN=CUR_TX_OUT_COUNT_LEN,
        CUR_TX_OUT_SIZE=CUR_TX_OUT_SIZE,
        CUR_TX_MAX_WITNESS_STACK_SIZE=CUR_TX_MAX_WITNESS_STACK_SIZE,
        CUR_TX_WITNESS_SIZE=CUR_TX_WITNESS_SIZE,
        CUR_IS_GEGWIT=str(CUR_TX_WITNESS_SIZE != 0).lower(),
        PREV_TX_INP_COUNT_LEN=PREV_TX_INP_COUNT_LEN,
        PREV_TX_INP_SIZE=PREV_TX_INP_SIZE,
        PREV_TX_OUT_COUNT_LEN=PREV_TX_OUT_COUNT_LEN,
        PREV_TX_OUT_SIZE=PREV_TX_OUT_SIZE,
        PREV_TX_MAX_WITNESS_STACK_SIZE=PREV_TX_MAX_WITNESS_STACK_SIZE,
        PREV_TX_WITNESS_SIZE=PREV_TX_WITNESS_SIZE,
        PREV_IS_GEGWIT=str(PREV_TX_WITNESS_SIZE != 0).lower(),
        opcodesAmount=0 if CUR_TX_WITNESS_SIZE != 0 else script.opcodes,
        curTxLen=curTx._get_transaction_size() * 2, 
        prevTxLen=prevTx._get_transaction_size() * 2, 
        signLen=1 if CUR_TX_WITNESS_SIZE != 0 else len(script_sig),
        scriptPubKeyLen=len(script_pub_key),
        inputWitnessLen=curTx._get_witness_size(curTx.witness[INPUT_TO_SIGN]) - 1,
        redeemScriptLen=len(script.script_elements[-1]) // 2,
        codeseparatorRedeemScriptLen=redeem_script.script_len_codeseparator,
        codeseparatorRedeemScriptLenLen=curTx._get_compact_size_size(redeem_script.script_len_codeseparator),
        redeemOpcodesAmount=redeem_script.opcodes,
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
        script_sig="-" if CUR_TX_WITNESS_SIZE != 0 else script_sig,
        input_to_sign=INPUT_TO_SIGN
    )

    with open(config["file_path"] + "/Prover.toml", "w") as file:
        file.write(proverFile)

if __name__ == "__main__":
    main()
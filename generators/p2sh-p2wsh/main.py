import json
from typing import Dict
from generators.utils.tx import Transaction
from generators.utils.script import Script
from generators.utils.opcodes_gen import generate

def get_config(path: str = "./generators/p2sh-p2wsh/config.json") -> Dict:
    with open(path, "r") as f:
        return json.load(f)

def main():
    print("Spending type: p2sh-p2wsh")
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
    CUR_TX_MAX_WITNESS_STACK_SIZE = 0 if curTx.witness is None else max(len(w.stack_items) for w in curTx.witness)
    CUR_TX_WITNESS_SIZE = sum(curTx._get_witness_size(wit) for wit in curTx.witness)

    PREV_TX_INP_COUNT_LEN = prevTx._get_compact_size_size(prevTx.input_count)
    PREV_TX_INP_SIZE = sum(prevTx._get_input_size(inp) for inp in prevTx.inputs) + PREV_TX_INP_COUNT_LEN
    PREV_TX_OUT_COUNT_LEN = prevTx._get_compact_size_size(prevTx.output_count)
    PREV_TX_OUT_SIZE = sum(prevTx._get_output_size(out) for out in prevTx.outputs) + PREV_TX_OUT_COUNT_LEN
    PREV_TX_MAX_WITNESS_STACK_SIZE = 0 if prevTx.witness is None else max(len(w.stack_items) for w in prevTx.witness)
    PREV_TX_WITNESS_SIZE = 0 if prevTx.witness == None else sum(prevTx._get_witness_size(wit) for wit in prevTx.witness)

    INPUT_TO_SIGN = config["input_to_sign"]

    script_pub_key = prevTx.outputs[vout].script_pub_key
    script_pub_key_size = prevTx.outputs[vout].script_pub_key_size

    script_sig = config["script_sig"]
    witness = curTx.witness_to_hex_script(INPUT_TO_SIGN)

    script = Script(script_sig + bytearray(script_pub_key).hex(), curTx, config["input_to_sign"])
    sizes = script.sizes

    full_script_sig = bytearray.fromhex(script.script_elements[-4])
    full_script_sig.pop(0)
    full_ss = [168]
    full_ss.extend(list(full_script_sig))
    full_ss.extend([135])
    full_script_sig = bytes(full_ss).hex()

    parsed_script_sig = Script(witness + full_script_sig, curTx, config["input_to_sign"], [])
    sizes = sizes | parsed_script_sig.sizes

    rds = bytearray.fromhex(parsed_script_sig.script_elements[-4]).hex()

    redeem_script = Script(rds, curTx, config["input_to_sign"], parsed_script_sig.script_elements[0:-4])
    sizes = sizes | redeem_script.sizes
    generate(sizes)

    require_stack_size = max(script.require_stack_size, parsed_script_sig.require_stack_size, redeem_script.require_stack_size)
    max_element_size = max(script.max_element_size, parsed_script_sig.max_element_size, redeem_script.max_element_size)

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
        redeemScriptLen=len(rds) // 2,
        codesepRedeemScriptLen=redeem_script.script_len_codeseparator,
        codesepRedeemScriptLenLen=curTx._get_compact_size_size(redeem_script.script_len_codeseparator),
        witnessFieldLen=len(witness),
        redeemScriptOpcodesAmount=redeem_script.opcodes,
        stackSize=require_stack_size,
        maxStackElementSize=max_element_size,
        nOutputSize=curTx._get_output_size(curTx.outputs[INPUT_TO_SIGN]) if len(curTx.outputs) > INPUT_TO_SIGN else 0,
        inputToSign=INPUT_TO_SIGN,
        inputToSignLen=curTx._get_compact_size_size(INPUT_TO_SIGN),
        nInputSize=curTx._get_input_size(curTx.inputs[INPUT_TO_SIGN]),
        opcodesAmount=parsed_script_sig.opcodes
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
        witness_script=witness,
        input_to_sign=INPUT_TO_SIGN
    )

    with open(config["file_path"] + "/Prover.toml", "w") as file:
        file.write(proverFile)

if __name__ == "__main__":
    main()
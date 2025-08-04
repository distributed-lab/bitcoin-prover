import json
from typing import Dict
from generators.utils.tx import Transaction
from generators.utils.script import Script
from generators.utils.opcodes_gen import generate
from generators.utils.taproot_utils import get_outputs_from_inputs

def get_config(path: str = "./generators/p2tr-script/config.json") -> Dict:
    with open(path, "r") as f:
        return json.load(f)

def main():
    print("Spending type: p2tr - script path spend")
    config = get_config()

    curTx = Transaction(config["cur_tx"])
    curTx.cut_script_sigs()

    prevTx = Transaction(config["prev_tx"])
    prevTx.cut_script_sigs()

    INPUT_TO_SIGN = config["input_to_sign"]

    witness = curTx.witness_to_hex_script(INPUT_TO_SIGN, 2)
    ws = Script(witness, curTx, 0, [])
    script = curTx.witness[INPUT_TO_SIGN].stack_items[-2].item
    script_parse = Script(script.hex(), curTx, config["input_to_sign"], [elem.item for elem in curTx.witness[INPUT_TO_SIGN].stack_items[:-2]])
    control_block = curTx.witness[INPUT_TO_SIGN].stack_items[-1].item
    sizes = ws.sizes | script_parse.sizes
    generate(sizes, True)

    with open(config["file_path"] + "/src/globals.nr.template", "r") as file:
        templateOpcodes = file.read()

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

    outpus = get_outputs_from_inputs(curTx)
    requireStackSize = ws.require_stack_size + script_parse.require_stack_size
    maxStackElementSize = max(script_parse.max_element_size, ws.max_element_size)

    opcodesFile = templateOpcodes.format(
        curTx=curTx, 
        prevTx=prevTx,
        utxosLen=len(outpus[0]),
        witnessScriptLen=len(witness),
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
        curTxLen=curTx._get_transaction_size() * 2, 
        prevTxLen=prevTx._get_transaction_size() * 2, 
        nOutputSize=curTx._get_output_size(curTx.outputs[INPUT_TO_SIGN]),
        scriptLen=len(script),
        scriptLenLen=curTx._get_compact_size_size(len(script)),
        scriptOpcodesAmount=script_parse.opcodes + ws.opcodes,
        controlBlockLen=len(control_block),
        stackSize=requireStackSize,
        maxStackElementSize=maxStackElementSize,
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
        utxosData=list_to_toml(outpus[0]),
        inputToSign=INPUT_TO_SIGN,
        witnessScript=witness
    )

    with open(config["file_path"] + "/Prover.toml", "w") as file:
        file.write(proverFile)

def list_to_toml(list) -> str:
    res = "["
    for elem in list:
        res += f'"{elem}", '
    
    res = res[:-2]
    res += "]" 
    return res

if __name__ == "__main__":
    main()
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

    with open(config["file_path"] + "/src/main.nr.template", "r") as file:
        templateMain = file.read()

    mainFile = templateMain.format(
        curTx=curTx, 
        config=config, 
        prevTx=prevTx, 
        curTxLen=len(curTx.txData), 
        prevTxLen=len(prevTx.txData), 
        signLen=len(config['signature']), 
        pkLen=len(config['pub_key'])
    )

    with open(config["file_path"] + "/src/main.nr", "w") as file:
        file.write(mainFile)
        
    with open(config["file_path"] + "/Prover.toml", "w") as file:
        file.write(f'''cur_tx_data = "{curTx.txData}"
prev_tx_data = "{prevTx.txData}"
signature = "{config["signature"]}"
pub_key = "{config["pub_key"]}"
input_to_sign = "{config["input_to_sign"]}"
''')
        
def proverify(val: List[int]) -> str:
    return '[' + ', '.join('"' + str(x) + '"' for x in val) + ']'

if __name__ == "__main__":
    main()
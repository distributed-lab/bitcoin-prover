import json
from typing import Dict

def get_config(path: str = "./generators/p2sh/config.json") -> Dict:
    with open(path, "r") as f:
        return json.load(f)
    
def main():
    config = get_config()

    with open(config["path"] + "/src/main.nr", "w") as file:
        file.write(f"""use p2sh_lib::{{check_script, check_opcodes, script_to_bytes}};
                   
global ADDR_LEN: u32 = {len(config['address'])};

fn main(script: str<{len(config['script'])}>, addr: pub str<ADDR_LEN>) -> pub bool {{
    check_script(script, addr) | check_opcodes(script_to_bytes(script)) 
}}
                   """)
        
    print("main.nr was generated")

    with open(config["path"] + "/Prover.toml", "w") as file:
        file.write(f'script = "{config["script"]}"\naddr = "{config["address"]}"')
    
    print("Prover.toml was generated")


if __name__ == "__main__":
    main()
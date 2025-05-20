import json
from typing import Dict

def get_config(path: str = "./config.json") -> Dict:
    with open(path, "r") as f:
        return json.load(f)
    
def main():
    config = get_config()

    with open(config["path"] + "/src/main.nr", "w") as file:
        file.write(f"""use base58::check_script;
                   
mod base58;
                   
global ADDR_LEN: u32 = {len(config['adress'])};

fn main(script: str<{len(config['script'])}>, addr: pub str<ADDR_LEN>) -> pub bool {{
    check_script(script, addr)
}}
                   """)
        
    print("main.nr was generated")

    with open(config["path"] + "/Prover.toml", "w") as file:
        file.write(f'script = "{config["script"]}"\naddr = "{config["adress"]}"')
    
    print("Prover.toml was generated")


if __name__ == "__main__":
    main()
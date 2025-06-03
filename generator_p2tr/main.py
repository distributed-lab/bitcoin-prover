import json
from typing import Dict

def get_config(path: str = "./config.json") -> Dict:
    with open(path, "r") as f:
        return json.load(f)
    
def main():
    config = get_config()

    N = len(config['scripts'])

    with open(config["path"] + "/src/main.nr", "w") as file:
        file.write(f"""use merkle_root::{{hash_from_script, get_branch}};
                   
mod merkle_root;
mod keys;
mod types;
                   
global N: u32 = {N};

fn main(
    address: str<62>, 
    priv_key: str<64>,
""")
        
        for idx, script in enumerate(config['scripts']):
            file.write(f"\tscript{idx + 1}: str<{len(script)}>,\n")
        
        file.write(f""") -> pub bool {{
    let mut scrs0: [[u8; 32]; {N}] = [[0; 32]; {N}];\n""")
        
        for i in range(1, N + 1):
            file.write(f"\tscrs0[{i - 1}] = hash_from_script(script{i});\n")

        file.write("\n")

        lvl = 0
        prev = 0
        while N != 1:
            lvl += 1
            prev = N
            N = N // 2 + N % 2
            file.write(f"\tlet mut scrs{lvl}: [[u8; 32]; {N}] = [[0; 32]; {N}];\n")
            for i in range(0, N):
                if i == N - 1 and prev % 2 == 1:
                    file.write(f"\tscrs{lvl}[{i}] = scrs{lvl - 1}[{2 * i}];\n")
                else:
                    file.write(f"\tscrs{lvl}[{i}] = get_branch(scrs{lvl - 1}[{2 * i}], scrs{lvl - 1}[{2 * i + 1}]);\n")


        file.write(f"""
    println(scrs{lvl}[0]);
    true
}}""")
        
    print("main.nr was generated")

    with open(config["path"] + "/Prover.toml", "w") as file:
        file.write(f'address = "{config["address"]}"\npriv_key = "{config["priv_key"]}"\n')

        for idx, script in enumerate(config['scripts']):
            file.write(f'script{idx + 1} = "{script}"\n')
    
    print("Prover.toml was generated")


if __name__ == "__main__":
    main()
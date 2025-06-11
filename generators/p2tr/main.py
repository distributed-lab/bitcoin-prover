import json
from typing import Dict

def get_config(path: str = "./generators/p2tr/config.json") -> Dict:
    with open(path, "r") as f:
        return json.load(f)
    
def main():
    config = get_config()

    with open(config["path"] + "/src/main.nr", "w") as file:
        file.write(f"""use dep::bignum::{{BigNum, U768}};
use utils::{{encode::encode_bech32m, convert::hex_to_bytes}};
use p2tr_lib::keys::{{get_tweaked_pub_key}};
use p2tr_lib::merkle_root::{{get_branch, hash_from_script}};
use crypto::types::{{I768, sqrt_secp256k}};
use crypto::point::Point;
use std::ops::{{Add, Mul}};
                   
global N: u32 = {len(config['script'])};

fn main(
    address: pub str<62>, 
    pub_key: str<64>,
    script: str<N>,
""")
        
        for idx in range(0, len(config['merklePath'])):
            file.write(f"\tnode{idx + 1}: str<64>,\n")
        
        file.write(f""") -> pub bool {{        
    let mut node: [u8; 32] = hash_from_script(script);\n""")
                
        for i in range(1, len(config['merklePath']) + 1):
            file.write(f"\tnode = get_branch(node, hex_to_bytes(node{i}));\n")

        file.write("""  
    let modulo: U768 = U768::from_be_bytes([
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFE, 0xFF, 0xFF, 0xFC, 0x2F,
    ]);
               
    let pub_x = I768 {
        num: U768::from_be_bytes([0; 65].as_slice().append(hex_to_bytes(pub_key)).as_array::<97>()),
        is_neg: false
    };
                   
    // y^2 = x^3 + 7
    let pub_y = sqrt_secp256k(pub_x.mul(pub_x).umod(modulo).mul(pub_x).add(I768::from(7)).umod(modulo));
                   
    let pub_key_point = Point { x: pub_x, y: pub_y, is_O: false};
    
    let twpk = get_tweaked_pub_key(pub_key_point, node);
               
    encode_bech32m(twpk.to_be_bytes().as_slice().pop_front().1.as_array()) == address
}
""")
        
    print("main.nr was generated")

    with open(config["path"] + "/Prover.toml", "w") as file:
        file.write(f'address = "{config["address"]}"\npub_key = "{config["pub_key"]}"\nscript = "{config["script"]}"\n')

        for idx, script in enumerate(config['merklePath']):
            file.write(f'node{idx + 1} = "{script}"\n')
    
    print("Prover.toml was generated")


if __name__ == "__main__":
    main()
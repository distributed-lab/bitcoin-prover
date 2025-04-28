from typing import List

BLOCK_HEADER_SIZE = 80

class Block:
    def __init__(self, header: str):
        self.version = header[:8]
        self.prev_hash = header[8:72]
        self.merkle_hash = header[72:136]
        self.time = header[136:144]
        self.nBits = header[144:152]
        self.nonce = header[152:]

    def to_toml_block(self) -> str:
        return f"version = \"{self.version}\"\n" + \
                f"prev_hash = \"{self.prev_hash}\"\n" + \
                f"merkle_hash = \"{self.merkle_hash}\"\n" + \
                f"time = \"{self.time}\"\n" + \
                f"nBits = \"{self.nBits}\"\n" + \
                f"nonce = \"{self.nonce}\"\n"


    def __str__(self) -> str:
        return self.to_toml_block()

def create_nargo_toml(blocks: List[Block], struct_name: str) -> str:
    nargo_field_blocks = map(lambda b: f"[[{struct_name}]]\n{b.to_toml_block()}", blocks)
    return "\n".join(nargo_field_blocks)

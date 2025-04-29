from typing import List

BLOCK_HEADER_SIZE = 80

class Block:
    def __init__(self, header: str):
        self.version = header[:8]
        self.prev_hash = ''.join([header[8:72][i:i+2] for i in range(0, len(header[8:72]), 2)][::-1])
        self.merkle_hash = ''.join([header[72:136][i:i+2] for i in range(0, len(header[72:136]), 2)][::-1])
        self.time = header[136:144]
        self.nBits = header[144:152]
        self.nonce = header[152:]

    def to_toml_block(self) -> str:
        return f"version = \"{int.from_bytes(bytes.fromhex(self.version), byteorder='little')}\"\n" + \
                f"prev_block = \"{self.prev_hash}\"\n" + \
                f"merkle_root = \"{self.merkle_hash}\"\n" + \
                f"timestamp = \"{int.from_bytes(bytes.fromhex(self.time), byteorder='little')}\"\n" + \
                f"bits = \"{int.from_bytes(bytes.fromhex(self.nBits), byteorder='little')}\"\n" + \
                f"nonce = \"{int.from_bytes(bytes.fromhex(self.nonce), byteorder='little')}\"\n"


    def __str__(self) -> str:
        return self.to_toml_block()

def create_nargo_toml(blocks: List[Block], struct_name: str) -> str:
    nargo_field_blocks = map(lambda b: f"[[{struct_name}]]\n{b.to_toml_block()}", blocks)
    return "\n".join(nargo_field_blocks)

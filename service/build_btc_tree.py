from generators.blocks.pullers import BlockHeaderPuller
from generators.blocks.block import Block
from service.merkle_tree import MerkleTree

gataway = {"host": "bolt.schulzemic.net", "port": 50001}
chunk_size = 1024

class BTCBlocksMerkleTree:
    def __init__(self, blocks_amount):
        puller = BlockHeaderPuller(gataway)
        hex_headers = puller.pull_block_headers(0, blocks_amount)
        blocks = [Block(header) for header in hex_headers]

        self.chunks = []
        for i in range(0, blocks_amount, chunk_size):
            amount = min(chunk_size, blocks_amount - i)
            tree = MerkleTree()
            for j in range(0, amount):
                tree.add_leaf(bytes.fromhex(blocks[i + j].get_block_hash()))
            self.chunks.append(tree)
        
        self.chunks_tree = MerkleTree(None, "leaf2", "node2")
        for i in range(0, len(self.chunks)):
            self.chunks_tree.add_leaf(self.chunks[i].root())

        self.chunks_tree.build_tree()

    def get_merkle_path(self, block_height):
        tree = self.chunks[block_height // chunk_size]
        merkle_path = tree.merkle_path(block_height % chunk_size)
        chunk_root = self.chunks_tree.hash_leaf(tree.root())
        chunk_index = self.chunks_tree.levels[0].index(chunk_root)
        merkle_path += self.chunks_tree.merkle_path(chunk_index)
        return merkle_path
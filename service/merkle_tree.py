import hashlib

class MerkleTree:
    def __init__(self, leaves=None, leaf_tag="leaf1", node_tag="node1"):
        self.leaf_tag = leaf_tag
        self.node_tag = node_tag
        self.leaves = []
        self.levels = []
        if leaves:
            for leaf in leaves:
                self.add_leaf(leaf)

    def hash_leaf(self, data: bytes) -> bytes:
        return hashlib.sha256(self.leaf_tag.encode() + data).digest()

    def hash_node(self, left: bytes, right: bytes) -> bytes:
        return hashlib.sha256(self.node_tag.encode() + left + right).digest()

    def add_leaf(self, data: bytes):
        self.leaves.append(self.hash_leaf(data))

    def build_tree(self):
        nodes = self.leaves[:]
        self.levels = [nodes]
        while len(nodes) > 1:
            next_level = []
            for i in range(0, len(nodes), 2):
                left = nodes[i]
                right = nodes[i+1] if i+1 < len(nodes) else nodes[i]
                next_level.append(self.hash_node(left, right))
            nodes = next_level
            self.levels.append(nodes)

    def root(self) -> bytes:
        if not self.levels:
            self.build_tree()
        return self.levels[-1][0] if self.levels else b''

    def merkle_path(self, index: int):
        """Повертає Merkle proof для листка з індексом index"""
        if not self.levels:
            self.build_tree()
        path = []
        for level in self.levels[:-1]:
            sibling_index = index ^ 1
            if sibling_index < len(level):
                path.append(level[sibling_index].hex())
            index //= 2
        return path


from service.build_btc_tree import BTCBlocksMerkleTree
from fastapi import FastAPI
from service.merkle_tree import MerkleTree

app = FastAPI()
tree = BTCBlocksMerkleTree(2048)

@app.on_event("startup")
async def startup_event():
    print(f"✅ Сервер запущено! Тепер можна стукати в API. (merkle root: {tree.chunks_tree.root().hex()})")

@app.get("/proof/{height}")
def get_proof(height: int):
    proof = tree.get_merkle_path(height)
    return {"proof": [p for p in proof]}


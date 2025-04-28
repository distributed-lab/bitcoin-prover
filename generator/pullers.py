from electrum_client.requests import BlockHeadersRequest
from electrum_client.rpc import Client as ElectrumClient
from typing import Dict, List
from block import BLOCK_HEADER_SIZE
import logging

class BlockHeaderPuller:
    """
    Pulls block headers from the Electrum server.
    """
    def __init__(self, gateway_config: Dict):
        self.client = ElectrumClient(gateway_config["host"], gateway_config["port"])

    def pull_block_headers(self, start: int, count: int, step: int = 2000) -> List[str]:
        logging.debug(f"Pulling {count} block headers starting from {start} with step {step}")
        answer = []
        for i in range(start, start + count, step):
            n_headers = min(step, start + count - i)
            logging.debug(f"Pulling {i} to {i + n_headers}")
            request = BlockHeadersRequest(i, n_headers)
            response = self.client.call(request)
            new_headers_concat_hex = response["result"]["hex"]
            assert len(new_headers_concat_hex) == 2 * BLOCK_HEADER_SIZE * n_headers
            for i in range(n_headers):
                new_header_hex = new_headers_concat_hex[2 * BLOCK_HEADER_SIZE * i: 2 * BLOCK_HEADER_SIZE * (i + 1)]
                answer.append(new_header_hex)
        return answer

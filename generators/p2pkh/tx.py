class Transaction:
    def __init__(self, txData: str, inputCount: int, inputSize: int, outputCount: int, outputSize: int, maxWitnessStackSize: int, witnessSize):
        self.txData = txData
        self.inputCount = inputCount
        self.inputSize = inputSize
        self.outputCount = outputCount
        self.outputSize = outputSize
        self.maxWitnessStackSize = maxWitnessStackSize
        self.witnessSize = witnessSize

def get_ready_tx(tx: str) -> Transaction:
    byteArray = bytearray.fromhex(tx)
    pos = 0
    match byteArray[4]:
        case 253:
            inpCount = int.from_bytes([byteArray[5:7]], byteorder='little')
            pos += 7
        case 254:
            inpCount = int.from_bytes([byteArray[5:9]], byteorder='little')
            pos += 9
        case 255:
            inpCount = int.from_bytes([byteArray[5:13]], byteorder='little')
            pos += 13
        case _:
            inpCount = byteArray[4]
            pos += 5

    for _ in range(inpCount):
        pos += 36
        match byteArray[pos]:
            case 253:
                sigSize = int.from_bytes([byteArray[(pos+1):(pos+3)]], byteorder='little')
                sigSize += 2
            case 254:
                sigSize = int.from_bytes([byteArray[(pos+1):(pos+5)]], byteorder='little')
                sigSize += 4
            case 255:
                sigSize = int.from_bytes([byteArray[(pos+1):(pos+9)]], byteorder='little')
                sigSize += 8
            case _:
                sigSize = byteArray[pos]
        byteArray[pos] = 0
        pos += 1
        del byteArray[pos:(pos+sigSize)]
        pos += 4

    match byteArray[pos]:
        case 253:
            outCount = int.from_bytes([byteArray[(pos+1):(pos+3)]], byteorder='little')
            pos += 3
        case 254:
            outCount = int.from_bytes([byteArray[(pos+1):(pos+5)]], byteorder='little')
            pos += 5
        case 255:
            outCount = int.from_bytes([byteArray[(pos+1):(pos+9)]], byteorder='little')
            pos += 9
        case _:
            outCount = byteArray[pos]
            pos += 1

    outSize = pos
    for _ in range(outCount):
        pos += 8
        match byteArray[pos]:
            case 253:
                scriptPubKeySize = int.from_bytes([byteArray[(pos+1):(pos+3)]], byteorder='little')
                pos += 3
            case 254:
                scriptPubKeySize = int.from_bytes([byteArray[(pos+1):(pos+5)]], byteorder='little')
                pos += 5
            case 255:
                scriptPubKeySize = int.from_bytes([byteArray[(pos+1):(pos+9)]], byteorder='little')
                pos += 9
            case _:
                scriptPubKeySize = byteArray[pos]
                pos += 1

        pos += scriptPubKeySize
    
    outSize = pos - outSize + 1

    pos += 4

    return Transaction(byteArray.hex(), inputCount=inpCount, inputSize=(41 * inpCount + 1), outputCount=outCount, outputSize=outSize, maxWitnessStackSize=0, witnessSize=0)

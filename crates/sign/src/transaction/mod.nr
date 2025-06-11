use std::hash::poseidon2::Poseidon2Hasher;
use std::hash::BuildHasherDefault;
use std::collections::map::HashMap;

pub mod compact_size;

pub struct PositionField {
    offset: u32,
    size: u32,
}

pub struct Input {
    txid: PositionField,
    vout: PositionField,
    script_sig_size: PositionField,
    script_sig: PositionField,
    sequence: PositionField,
}

impl Input {
    fn default() -> Self {
        Self {
            txid: PositionField { offset: 0, size: 0 },
            vout: PositionField { offset: 0, size: 0 },
            script_sig_size: PositionField { offset: 0, size: 0 },
            script_sig: PositionField { offset: 0, size: 0 },
            sequence: PositionField { offset: 0, size: 0 },
        }
    }
}

pub struct Output {
    amount: PositionField,
    script_pub_key_size: PositionField,
    script_pub_key: PositionField,
}

impl Output {
    fn default() -> Self {
        Self {
            amount: PositionField { offset: 0, size: 0 },
            script_pub_key_size: PositionField { offset: 0, size: 0 },
            script_pub_key: PositionField { offset: 0, size: 0 },
        }
    }
}

pub struct WitnessItem {
    size: PositionField,
    item: PositionField,
}

impl WitnessItem {
    fn default() -> Self {
        Self {
            size: PositionField { offset: 0, size: 0 },
            item: PositionField { offset: 0, size: 0 },
        }
    }
}

pub struct Witness {
    stack_size: PositionField,
    items: HashMap<u32, WitnessItem, 100, BuildHasherDefault<Poseidon2Hasher>>,
}

impl Witness {
    fn default() -> Self {
        Self {
            stack_size: PositionField { offset: 0, size: 0 },
            items: HashMap::default(),
        }
    }
}

pub struct Transaction<
    let TRANSACTION_SIZE: u32,
    let INPUT_COUNT: u32,
    let OUTPUT_COUNT: u32,
    let MAX_WITNESS_STACK_SIZE: u32,
> {
    data: [u8; TRANSACTION_SIZE],
    version: PositionField,
    marker: Option<PositionField>,
    flag: Option<PositionField>,
    input_count: PositionField,
    inputs: [Input; INPUT_COUNT],
    output_count: PositionField,
    outputs: [Output; OUTPUT_COUNT],
    witness: Option<[Witness; INPUT_COUNT]>,
    lock_time: PositionField,
}

impl<
    let TRANSACTION_SIZE: u32,
    let INPUT_COUNT: u32,
    let OUTPUT_COUNT: u32,
    let MAX_WITNESS_STACK_SIZE: u32,
> Transaction<
    TRANSACTION_SIZE,
    INPUT_COUNT,
    OUTPUT_COUNT,
    MAX_WITNESS_STACK_SIZE,
> {
    fn new(data: [u8; TRANSACTION_SIZE], segwit: bool) -> Self {
        let mut cur_pos: u32 = 0;

        let version = PositionField { offset: cur_pos, size: 4 };
        cur_pos += 4;

        let mut marker = Option::none();
        if segwit {
            marker = Option::some(PositionField { offset: cur_pos, size: 1 });
            cur_pos += 1;
        }

        let mut flag = Option::none();
        if segwit {
            flag = Option::some(PositionField { offset: cur_pos, size: 1 });
            cur_pos += 1;
        }

        let input_count = compact_size::get_compact_size(data, cur_pos);
        cur_pos += input_count.size;

        let mut inputs: [Input; INPUT_COUNT] = [Input::default(); INPUT_COUNT];
        for i in 0..INPUT_COUNT {
            let txid = PositionField { offset: cur_pos, size: 32 };
            cur_pos += 32;

            let vout = PositionField { offset: cur_pos, size: 4 };
            cur_pos += 4;

            let script_sig_size = compact_size::get_compact_size(data, cur_pos);
            cur_pos += script_sig_size.size;

            let script_sig_size_u32 = compact_size::compact_size_to_u32(data, script_sig_size);
            let script_sig = PositionField { offset: cur_pos, size: script_sig_size_u32 };
            cur_pos += script_sig_size_u32;

            let sequence = PositionField { offset: cur_pos, size: 4 };
            cur_pos += 4;

            inputs[i] = Input {
                txid,
                vout,
                script_sig_size,
                script_sig,
                sequence,
            };
        }

        let output_count = compact_size::get_compact_size(data, cur_pos);
        cur_pos += output_count.size;

        let mut outputs: [Output; OUTPUT_COUNT] = [Output::default(); OUTPUT_COUNT];
        for i in 0..OUTPUT_COUNT {
            let amount = PositionField { offset: cur_pos, size: 8 };
            cur_pos += 8;

            let script_pub_key_size = compact_size::get_compact_size(data, cur_pos);
            cur_pos += script_pub_key_size.size;

            let script_pub_key_size_u32 = compact_size::compact_size_to_u32(data, script_pub_key_size);
            let script_pub_key = PositionField { offset: cur_pos, size: script_pub_key_size_u32 };
            cur_pos += script_pub_key_size_u32;

            outputs[i] = Output {
                amount,
                script_pub_key_size,
                script_pub_key,
            };
        }

        let mut witness = Option::none();
        if segwit {
            let mut all_witness: [Witness; INPUT_COUNT] = [Witness::default(); INPUT_COUNT];
            for i in 0..INPUT_COUNT {
                let stack_size = compact_size::get_compact_size(data, cur_pos);
                cur_pos += stack_size.size;

                let stack_size_u32 = compact_size::compact_size_to_u32(data, stack_size);
                let mut items: HashMap<u32, WitnessItem, 100, BuildHasherDefault<Poseidon2Hasher>> = HashMap::default();

                assert(stack_size_u32 <= MAX_WITNESS_STACK_SIZE);
                for j in 0..MAX_WITNESS_STACK_SIZE {
                    if j < stack_size_u32 {
                        let size = compact_size::get_compact_size(data, cur_pos);
                        cur_pos += size.size;

                        let size_u32 = compact_size::compact_size_to_u32(data, size);
                        let item = PositionField { offset: cur_pos, size: size_u32 };
                        cur_pos += size_u32;

                        items.insert(j, WitnessItem {
                            size,
                            item,
                        });
                    }
                }

                all_witness[i] = Witness {
                    stack_size,
                    items,
                };
            }

            witness = Option::some(all_witness);
        }

        let lock_time = PositionField { offset: cur_pos, size: 4 };
        cur_pos += 4;

        Self {
            data,
            version,
            marker,
            flag,
            input_count,
            inputs,
            output_count,
            outputs,
            witness,
            lock_time,
        }
    }
}

pub(crate) fn hex_symbol_to_byte(value: u8) -> u8 {
    if value < 58 {
        value - 48
    } else {
        value - 87
    }
}

pub(crate) fn byte_to_hex_symbol(value: u8) -> u8 {
    if value <= 9 {
        value + 48
    } else {
        value + 87
    }
}

pub(crate) fn hex_to_bytes<let N: u32>(value: str<2*N>) -> [u8; N] {
    let mut res = [0; N];
    let value = value.as_bytes();
    for i in 0..N {
        let left =  hex_symbol_to_byte(value[i << 1]);
        let right = hex_symbol_to_byte(value[(i << 1) + 1]);
        res[i] = (left << 4) + right;
    }
    res
}

pub(crate) fn bytes_to_hex<let N: u32>(bytes: [u8; N]) -> str<2*N> {
    let mut res = [0; 2*N];
    for i in 0..N {
        res[i << 1] = byte_to_hex_symbol(bytes[i] >> 4);
        res[(i << 1) + 1] = byte_to_hex_symbol(bytes[i] & 0xf);
    }
    res.as_str_unchecked()
}

#[test]
fn test_transaction_creation() {
    let string: str<446> = "0100000001a77618edf4b1b47885f643ea7c6349598053eb1b1b879dd698085aa97bc03fb4010000006a473044022000dc119d89dc8499dbfb7e0361e78a450013bfadc20ef8e011a444750c467aaa02200637fe44dd4950f16f4fea64b59fcc2980eb4650c582b5da5bf4b2134474dcd2012102d20b39b3b90f53677e953f39ad3a61655a1c57f98635ea70933839ce3e4e416affffffff02a08601000000000017a91499b5a29770085fc856f717cc7e52a46b2361aa9a8786960c00000000001976a91440a64639e2fbcbc593e7c257c33ea615c83c8c6788ac00000000";

    let bytes = hex_to_bytes(string);
    let transaction = Transaction::<223, 1, 2, 2>::new(bytes, false);

    let txid_offset = transaction.inputs[0].txid.offset;
    let txid_size = transaction.inputs[0].txid.size;
    
    assert(txid_size == 32);
    let mut txid_bytes = [0; 32];
    for i in 0..32 {
        txid_bytes[i] = bytes[txid_offset + i];
    }

    let txid = bytes_to_hex(txid_bytes);

    assert(txid == "a77618edf4b1b47885f643ea7c6349598053eb1b1b879dd698085aa97bc03fb4");
}

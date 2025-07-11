use crate::opcode::{
    OP_0, OP_1, OP_16, OP_1NEGATE, OP_CHECKMULSIG, OP_CHECKMULSIGVERIFY, OP_CHECKSIG,
    OP_CHECKSIGVERIFY, OP_DUP, OP_EQUAL, OP_EQUALVERIFY, OP_HASH160, OP_PUSHBYTES1, OP_PUSHBYTES75,
    OP_PUSHDATA1, OP_PUSHDATA2, OP_PUSHDATA4,
};
use bvm::stack::{empty_stack_array, Stack};
use sign::address::Address;
use sign::transaction::Transaction;
use utils::convert::hex_to_bytes;

pub struct ScriptExecutionEngine<let MAX_STACK_ELEMENT_SIZE: u32, let MAX_STACK_SIZE: u32, let CURRENT_TRANSACTION_SIZE: u32, let CURRENT_INPUT_COUNT: u32, let CURRENT_INPUT_COUNT_LEN: u32, let CURRENT_INPUT_SIZE: u32, let CURRENT_OUTPUT_COUNT: u32, let CURRENT_OUTPUT_COUNT_LEN: u32, let CURRENT_OUTPUT_SIZE: u32, let CURRENT_MAX_WITNESS_STACK_SIZE: u32, let CURRENT_WITNESS_SIZE: u32, let PREV_TRANSACTION_SIZE: u32, let PREV_INPUT_COUNT: u32, let PREV_INPUT_COUNT_LEN: u32, let PREV_INPUT_SIZE: u32, let PREV_OUTPUT_COUNT: u32, let PREV_OUTPUT_COUNT_LEN: u32, let PREV_OUTPUT_SIZE: u32, let PREV_MAX_WITNESS_STACK_SIZE: u32, let PREV_WITNESS_SIZE: u32> {
    pub stack: Stack<MAX_STACK_ELEMENT_SIZE, MAX_STACK_SIZE, CURRENT_TRANSACTION_SIZE, CURRENT_INPUT_COUNT, CURRENT_INPUT_COUNT_LEN, CURRENT_INPUT_SIZE, CURRENT_OUTPUT_COUNT, CURRENT_OUTPUT_COUNT_LEN, CURRENT_OUTPUT_SIZE, CURRENT_MAX_WITNESS_STACK_SIZE, CURRENT_WITNESS_SIZE, PREV_TRANSACTION_SIZE, PREV_INPUT_COUNT, PREV_INPUT_COUNT_LEN, PREV_INPUT_SIZE, PREV_OUTPUT_COUNT, PREV_OUTPUT_COUNT_LEN, PREV_OUTPUT_SIZE, PREV_MAX_WITNESS_STACK_SIZE, PREV_WITNESS_SIZE>,
}

impl<let MAX_STACK_ELEMENT_SIZE: u32, let MAX_STACK_SIZE: u32, let CURRENT_TRANSACTION_SIZE: u32, let CURRENT_INPUT_COUNT: u32, let CURRENT_INPUT_COUNT_LEN: u32, let CURRENT_INPUT_SIZE: u32, let CURRENT_OUTPUT_COUNT: u32, let CURRENT_OUTPUT_COUNT_LEN: u32, let CURRENT_OUTPUT_SIZE: u32, let CURRENT_MAX_WITNESS_STACK_SIZE: u32, let CURRENT_WITNESS_SIZE: u32, let PREV_TRANSACTION_SIZE: u32, let PREV_INPUT_COUNT: u32, let PREV_INPUT_COUNT_LEN: u32, let PREV_INPUT_SIZE: u32, let PREV_OUTPUT_COUNT: u32, let PREV_OUTPUT_COUNT_LEN: u32, let PREV_OUTPUT_SIZE: u32, let PREV_MAX_WITNESS_STACK_SIZE: u32, let PREV_WITNESS_SIZE: u32> ScriptExecutionEngine<MAX_STACK_ELEMENT_SIZE, MAX_STACK_SIZE, CURRENT_TRANSACTION_SIZE, CURRENT_INPUT_COUNT, CURRENT_INPUT_COUNT_LEN, CURRENT_INPUT_SIZE, CURRENT_OUTPUT_COUNT, CURRENT_OUTPUT_COUNT_LEN, CURRENT_OUTPUT_SIZE, CURRENT_MAX_WITNESS_STACK_SIZE, CURRENT_WITNESS_SIZE, PREV_TRANSACTION_SIZE, PREV_INPUT_COUNT, PREV_INPUT_COUNT_LEN, PREV_INPUT_SIZE, PREV_OUTPUT_COUNT, PREV_OUTPUT_COUNT_LEN, PREV_OUTPUT_SIZE, PREV_MAX_WITNESS_STACK_SIZE, PREV_WITNESS_SIZE> {
    pub fn new(
        stack: Stack<MAX_STACK_ELEMENT_SIZE, MAX_STACK_SIZE, CURRENT_TRANSACTION_SIZE, CURRENT_INPUT_COUNT, CURRENT_INPUT_COUNT_LEN, CURRENT_INPUT_SIZE, CURRENT_OUTPUT_COUNT, CURRENT_OUTPUT_COUNT_LEN, CURRENT_OUTPUT_SIZE, CURRENT_MAX_WITNESS_STACK_SIZE, CURRENT_WITNESS_SIZE, PREV_TRANSACTION_SIZE, PREV_INPUT_COUNT, PREV_INPUT_COUNT_LEN, PREV_INPUT_SIZE, PREV_OUTPUT_COUNT, PREV_OUTPUT_COUNT_LEN, PREV_OUTPUT_SIZE, PREV_MAX_WITNESS_STACK_SIZE, PREV_WITNESS_SIZE>,
    ) -> Self {
        Self { stack: stack }
    }

    pub fn execute<let SCRIPT_SIZE: u32, let MAX_NUMBER_OF_OPCODES: u32, let STACK_ELEMENT_LENGTH_1: u32, let STACK_ELEMENT_LENGTH_2: u32, let STACK_ELEMENT_LENGTH_3: u32, let STACK_ELEMENT_LENGTH_4: u32, let STACK_ELEMENT_LENGTH_5: u32, let STACK_ELEMENT_LENGTH_6: u32, let SCRIPT_CODE_LEN_1: u32, let SCRIPT_CODE_LEN_2: u32, let SCRIPT_CODE_LEN_3: u32, let SCRIPT_CODE_LEN_4: u32, let SCRIPT_CODE_LEN_5: u32, let N1: u32, let M1: u32>(
        &mut self,
        script: [u8; SCRIPT_SIZE],
        address: Address,
    ) {
        let mut cur_pos = 0;

        for _ in 0..MAX_NUMBER_OF_OPCODES {
            if cur_pos < SCRIPT_SIZE {
                let opcode = script[cur_pos];
                cur_pos += 1;

                if opcode == OP_0 {
                    self.stack.op_num(0);
                } else if opcode >= OP_PUSHBYTES1 & opcode <= OP_PUSHBYTES75 {
                    // Handle push bytes with different lengths
                    let push_length = opcode as u32;

                    if push_length == STACK_ELEMENT_LENGTH_1 {
                        let mut value = [0; STACK_ELEMENT_LENGTH_1];
                        for i in 0..STACK_ELEMENT_LENGTH_1 {
                            value[i] = script[cur_pos];
                            cur_pos += 1;
                        }
                        self.stack.push_bytes(value);
                    } else if push_length == STACK_ELEMENT_LENGTH_2 {
                        let mut value = [0; STACK_ELEMENT_LENGTH_2];
                        for i in 0..STACK_ELEMENT_LENGTH_2 {
                            value[i] = script[cur_pos];
                            cur_pos += 1;
                        }
                        self.stack.push_bytes(value);
                    } else if push_length == STACK_ELEMENT_LENGTH_3 {
                        let mut value = [0; STACK_ELEMENT_LENGTH_3];
                        for i in 0..STACK_ELEMENT_LENGTH_3 {
                            value[i] = script[cur_pos];
                            cur_pos += 1;
                        }
                        self.stack.push_bytes(value);
                    } else if push_length == STACK_ELEMENT_LENGTH_4 {
                        let mut value = [0; STACK_ELEMENT_LENGTH_4];
                        for i in 0..STACK_ELEMENT_LENGTH_4 {
                            value[i] = script[cur_pos];
                            cur_pos += 1;
                        }
                        self.stack.push_bytes(value);
                    } else if push_length == STACK_ELEMENT_LENGTH_5 {
                        let mut value = [0; STACK_ELEMENT_LENGTH_5];
                        for i in 0..STACK_ELEMENT_LENGTH_5 {
                            value[i] = script[cur_pos];
                            cur_pos += 1;
                        }
                        self.stack.push_bytes(value);
                    } else if push_length == STACK_ELEMENT_LENGTH_6 {
                        let mut value = [0; STACK_ELEMENT_LENGTH_6];
                        for i in 0..STACK_ELEMENT_LENGTH_6 {
                            value[i] = script[cur_pos];
                            cur_pos += 1;
                        }
                        self.stack.push_bytes(value);
                    }
                } else if opcode >= OP_1 & opcode <= OP_16 {
                    self.stack.op_num(opcode as i8 - 80);
                } else if opcode == OP_DUP {
                    self.stack.op_dup();
                } else if opcode == OP_HASH160 {
                    let last_stack_element_length = self.stack.get_last_stack_element_length();

                    if last_stack_element_length == STACK_ELEMENT_LENGTH_1 {
                        self.stack.op_hash160::<STACK_ELEMENT_LENGTH_1>();
                    } else if last_stack_element_length == STACK_ELEMENT_LENGTH_2 {
                        self.stack.op_hash160::<STACK_ELEMENT_LENGTH_2>();
                    } else if last_stack_element_length == STACK_ELEMENT_LENGTH_3 {
                        self.stack.op_hash160::<STACK_ELEMENT_LENGTH_3>();
                    } else if last_stack_element_length == STACK_ELEMENT_LENGTH_4 {
                        self.stack.op_hash160::<STACK_ELEMENT_LENGTH_4>();
                    } else if last_stack_element_length == STACK_ELEMENT_LENGTH_5 {
                        self.stack.op_hash160::<STACK_ELEMENT_LENGTH_5>();
                    } else if last_stack_element_length == STACK_ELEMENT_LENGTH_6 {
                        self.stack.op_hash160::<STACK_ELEMENT_LENGTH_6>();
                    } else {
                        assert(false, "wrong stack element length");
                    }
                } else if opcode == OP_EQUAL {
                    self.stack.op_equal();
                } else if opcode == OP_EQUALVERIFY {
                    self.stack.op_equalverify();
                } else if (opcode == OP_CHECKSIG) | (opcode == OP_CHECKSIGVERIFY) {
                    let script_code_size = self.stack.get_script_code_size(address);
                    let verify = opcode == OP_CHECKSIGVERIFY;

                    if script_code_size == SCRIPT_CODE_LEN_1 {
                        self.stack.op_checksig::<SCRIPT_CODE_LEN_1>(address, verify);
                    } else if script_code_size == SCRIPT_CODE_LEN_2 {
                        self.stack.op_checksig::<SCRIPT_CODE_LEN_2>(address, verify);
                    } else if script_code_size == SCRIPT_CODE_LEN_3 {
                        self.stack.op_checksig::<SCRIPT_CODE_LEN_3>(address, verify);
                    } else if script_code_size == SCRIPT_CODE_LEN_4 {
                        self.stack.op_checksig::<SCRIPT_CODE_LEN_4>(address, verify);
                    } else if script_code_size == SCRIPT_CODE_LEN_5 {
                        self.stack.op_checksig::<SCRIPT_CODE_LEN_5>(address, verify);
                    } else {
                        assert(false, "wrong script code size");
                    }
                } else if (opcode == OP_CHECKMULSIG) | (opcode == OP_CHECKMULSIGVERIFY) {
                    let script_code_size = self.stack.get_script_code_size(address);
                    let verify = opcode == OP_CHECKMULSIGVERIFY;

                    if script_code_size == SCRIPT_CODE_LEN_1 {
                        self.stack.op_checkmulsig::<SCRIPT_CODE_LEN_1, N1, M1>(address, verify);
                    } else {
                        assert(false, "wrong script code size");
                    }
                }
            }
        }
    }
}

global TEST_SCRIPT_SIG_SIZE: u32 = 139;
global TEST_SCRIPT_PUB_KEY_SIZE: u32 = 25;
global TEST_MAX_NUMBER_OF_OPCODES: u32 = 7;
global TEST_STACK_ELEMENT_LENGTH_1: u32 = 65;
global TEST_STACK_ELEMENT_LENGTH_2: u32 = 72;
global TEST_STACK_ELEMENT_LENGTH_3: u32 = 20;
global TEST_STACK_ELEMENT_LENGTH_4: u32 = 1;
global TEST_STACK_ELEMENT_LENGTH_5: u32 = 1;
global TEST_STACK_ELEMENT_LENGTH_6: u32 = 1;
global TEST_SCRIPT_CODE_LEN_1: u32 = 26;
global TEST_SCRIPT_CODE_LEN_2: u32 = 1;
global TEST_SCRIPT_CODE_LEN_3: u32 = 1;
global TEST_SCRIPT_CODE_LEN_4: u32 = 1;
global TEST_SCRIPT_CODE_LEN_5: u32 = 1;

#[test]
fn test_p2pkh_execution() {
    // From here: https://www.blockchain.com/explorer/transactions/btc/12e753ef5cc30925a6eee2c457aa7f53022443ca013ea81882a6b59b69e342a6
    // Transaction with deleted script sigs
    let cur_tx_hex = "01000000030dd7891efbf67da47c651531db8aab3144ed7a524e4ae1e30b773525e27ddd7b0000000000ffffffff16851666962e37a75a246101f2e340c628b1db3c045d4d3cfb2d1c0f58f97c6f0000000000ffffffffffda5d38e91fd9a0d92872d51f83cb746fc7bf5d3ff13402f8d0d5ed60ddc79c0000000000ffffffff02c0c62d00000000001976a91417194e1bd175fb5b1b2a1f9d221f6f5c29e1928388ac00c817a8040000001976a91465bda9b05f7e9a8f96a7f4ba0996a877708ef90888ac00000000";
    let cur_tx_bytes = hex_to_bytes(cur_tx_hex);
    let cur_tx = Transaction::<201, 3, 1, 124, 2, 1, 69, 0, 0>::new(cur_tx_bytes, false);

    let input_to_sign = 1;

    // From here: https://www.blockchain.com/explorer/transactions/btc/6f7cf9580f1c2dfb3c4d5d043cdbb128c640e3f20161245aa7372e9666168516
    let prev_tx_hex = "0100000002f60b5e96f09422354ab150b0e506c4bffedaf20216d30059cc5a3061b4c83dff000000004a493046022100e26d9ff76a07d68369e5782be3f8532d25ecc8add58ee256da6c550b52e8006b022100b4431f5a9a4dcb51cbdcaae935218c0ae4cfc8aa903fe4e5bac4c208290b7d5d01fffffffff7272ef43189f5553c2baea50f59cde99b3220fd518884d932016d055895b62d000000004a493046022100a2ab7cdc5b67aca032899ea1b262f6e8181060f5a34ee667a82dac9c7b7db4c3022100911bc945c4b435df8227466433e56899fbb65833e4853683ecaa12ee840d16bf01ffffffff0100e40b54020000001976a91412ab8dc588ca9d5787dde7eb29569da63c3a238c88ac00000000";
    let prev_tx_bytes = hex_to_bytes(prev_tx_hex);
    let prev_tx = Transaction::<274, 2, 1, 231, 1, 1, 35, 0, 0>::new(prev_tx_bytes, false);

    let output_to_unlock = 0;

    let mut stack = Stack::new(
        cur_tx,
        prev_tx,
        input_to_sign,
        output_to_unlock,
        empty_stack_array::<80, 7>(),
    );

    let mut script_execution_engine = ScriptExecutionEngine::new(stack);

    let script_sig_key_hex = "48304502203f004eeed0cef2715643e2f25a27a28f3c578e94c7f0f6a4df104e7d163f7f8f022100b8b248c1cfd8f77a0365107a9511d759b7544d979dd152a955c867afac0ef7860141044d05240cfbd8a2786eda9dadd520c1609b8593ff8641018d57703d02ba687cf2f187f0cee2221c3afb1b5ff7888caced2423916b61444666ca1216f26181398c";
    let script_sig_key_bytes = hex_to_bytes(script_sig_key_hex);

    script_execution_engine
        .execute::<TEST_SCRIPT_SIG_SIZE, TEST_MAX_NUMBER_OF_OPCODES, TEST_STACK_ELEMENT_LENGTH_1, TEST_STACK_ELEMENT_LENGTH_2, TEST_STACK_ELEMENT_LENGTH_3, TEST_STACK_ELEMENT_LENGTH_4, TEST_STACK_ELEMENT_LENGTH_5, TEST_STACK_ELEMENT_LENGTH_6, TEST_SCRIPT_CODE_LEN_1, TEST_SCRIPT_CODE_LEN_2, TEST_SCRIPT_CODE_LEN_3, TEST_SCRIPT_CODE_LEN_4, TEST_SCRIPT_CODE_LEN_5, 0, 0>(
            script_sig_key_bytes,
            Address::new_script_sig(),
        );

    let script_pub_key_hex = "76a91412ab8dc588ca9d5787dde7eb29569da63c3a238c88ac";
    let script_pub_key_bytes = hex_to_bytes(script_pub_key_hex);

    script_execution_engine
        .execute::<TEST_SCRIPT_PUB_KEY_SIZE, TEST_MAX_NUMBER_OF_OPCODES, TEST_STACK_ELEMENT_LENGTH_1, TEST_STACK_ELEMENT_LENGTH_2, TEST_STACK_ELEMENT_LENGTH_3, TEST_STACK_ELEMENT_LENGTH_4, TEST_STACK_ELEMENT_LENGTH_5, TEST_STACK_ELEMENT_LENGTH_6, TEST_SCRIPT_CODE_LEN_1, TEST_SCRIPT_CODE_LEN_2, TEST_SCRIPT_CODE_LEN_3, TEST_SCRIPT_CODE_LEN_4, TEST_SCRIPT_CODE_LEN_5, 0, 0>(
            script_pub_key_bytes,
            Address::new_p2pkh(),
        );
}

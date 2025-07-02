use bvm::stack::Stack;
use crate::opcode::{
    OP_0, OP_PUSHBYTES1, OP_PUSHBYTES75, OP_PUSHDATA1, OP_PUSHDATA2, 
    OP_PUSHDATA4, OP_1NEGATE, OP_1, OP_16, OP_DUP, OP_HASH160, OP_EQUAL, 
    OP_EQUALVERIFY, OP_CHECKSIG
};
use sign::address::Address;

pub fn execution<
    let MAX_STACK_ELEMENT_SIZE: u32, 
    let MAX_STACK_SIZE: u32, 
    let CURRENT_TRANSACTION_SIZE: u32, 
    let CURRENT_INPUT_COUNT: u32, 
    let CURRENT_INPUT_COUNT_LEN: u32, 
    let CURRENT_INPUT_SIZE: u32, 
    let CURRENT_OUTPUT_COUNT: u32, 
    let CURRENT_OUTPUT_COUNT_LEN: u32, 
    let CURRENT_OUTPUT_SIZE: u32, 
    let CURRENT_MAX_WITNESS_STACK_SIZE: u32, 
    let CURRENT_WITNESS_SIZE: u32,
    let PREV_TRANSACTION_SIZE: u32,
    let PREV_INPUT_COUNT: u32,
    let PREV_INPUT_COUNT_LEN: u32,
    let PREV_INPUT_SIZE: u32,
    let PREV_OUTPUT_COUNT: u32,
    let PREV_OUTPUT_COUNT_LEN: u32,
    let PREV_OUTPUT_SIZE: u32,
    let PREV_MAX_WITNESS_STACK_SIZE: u32,
    let PREV_WITNESS_SIZE: u32,
    let MAX_NUMBER_OF_OPCODES: u32,
    let SCRIPT_SIZE: u32,
    let STACK_ELEMENT_LENGTH_1: u32,
    let STACK_ELEMENT_LENGTH_2: u32,
    let STACK_ELEMENT_LENGTH_3: u32,
    let STACK_ELEMENT_LENGTH_4: u32,
    let STACK_ELEMENT_LENGTH_5: u32,
    let SCRIPT_CODE_LEN_1: u32,
    let SCRIPT_CODE_LEN_2: u32,
    let SCRIPT_CODE_LEN_3: u32,
    let SCRIPT_CODE_LEN_4: u32,
    let SCRIPT_CODE_LEN_5: u32,
>(
    mut stack: Stack<
        MAX_STACK_ELEMENT_SIZE,
        MAX_STACK_SIZE,
        CURRENT_TRANSACTION_SIZE,
        CURRENT_INPUT_COUNT,
        CURRENT_INPUT_COUNT_LEN,
        CURRENT_INPUT_SIZE,
        CURRENT_OUTPUT_COUNT,
        CURRENT_OUTPUT_COUNT_LEN,
        CURRENT_OUTPUT_SIZE,
        CURRENT_MAX_WITNESS_STACK_SIZE,
        CURRENT_WITNESS_SIZE,
        PREV_TRANSACTION_SIZE,
        PREV_INPUT_COUNT,
        PREV_INPUT_COUNT_LEN,
        PREV_INPUT_SIZE,
        PREV_OUTPUT_COUNT,
        PREV_OUTPUT_COUNT_LEN,
        PREV_OUTPUT_SIZE,
        PREV_MAX_WITNESS_STACK_SIZE,
        PREV_WITNESS_SIZE,
    >,
    script: [u8; SCRIPT_SIZE],
    address: Address,
) {
    let mut cur_pos = 0;

    for _ in 0..MAX_NUMBER_OF_OPCODES {
        if cur_pos < SCRIPT_SIZE {
            let opcode = script[cur_pos];
            cur_pos += 1;

            if opcode == OP_0 {
                // do nothing
            } else if opcode >= OP_PUSHBYTES1 & opcode <= OP_PUSHBYTES75 {
                // Handle push bytes with different lengths
                let push_length = opcode as u32;
                
                if push_length == STACK_ELEMENT_LENGTH_1 {
                    let mut value = [0; STACK_ELEMENT_LENGTH_1];
                    for i in 0..STACK_ELEMENT_LENGTH_1 {
                        value[i] = script[cur_pos];
                        cur_pos += 1;
                    }
                    stack.push_bytes(value);
                } else if push_length == STACK_ELEMENT_LENGTH_2 {
                    let mut value = [0; STACK_ELEMENT_LENGTH_2];
                    for i in 0..STACK_ELEMENT_LENGTH_2 {
                        value[i] = script[cur_pos];
                        cur_pos += 1;
                    }
                    stack.push_bytes(value);
                } else if push_length == STACK_ELEMENT_LENGTH_3 {
                    let mut value = [0; STACK_ELEMENT_LENGTH_3];
                    for i in 0..STACK_ELEMENT_LENGTH_3 {
                        value[i] = script[cur_pos];
                        cur_pos += 1;
                    }
                    stack.push_bytes(value);
                } else if push_length == STACK_ELEMENT_LENGTH_4 {
                    let mut value = [0; STACK_ELEMENT_LENGTH_4];
                    for i in 0..STACK_ELEMENT_LENGTH_4 {
                        value[i] = script[cur_pos];
                        cur_pos += 1;
                    }
                    stack.push_bytes(value);
                } else if push_length == STACK_ELEMENT_LENGTH_5 {
                    let mut value = [0; STACK_ELEMENT_LENGTH_5];
                    for i in 0..STACK_ELEMENT_LENGTH_5 {
                        value[i] = script[cur_pos];
                        cur_pos += 1;
                    }
                    stack.push_bytes(value);
                }
            } else if opcode >= OP_1 & opcode <= OP_16 {
                stack.op_num(opcode as i8);
            } else if opcode == OP_DUP {
                stack.op_dup();
            } else if opcode == OP_HASH160 {
                stack.op_hash160();
            } else if opcode == OP_EQUAL {
                stack.op_equal();
            } else if opcode == OP_EQUALVERIFY {
                stack.op_equalverify();
            } else if opcode == OP_CHECKSIG {
                stack.op_checksig::<SCRIPT_CODE_LEN_1>(address);
            }
        }
    }

}

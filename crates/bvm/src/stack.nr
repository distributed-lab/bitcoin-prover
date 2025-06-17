use std::collections::bounded_vec::BoundedVec;
use sign::transaction::Transaction;

use utils::convert::{
    bytes_to_vec, i32_to_le_bytes, i32_to_vec, u32_to_le_bytes, vec_to_i32, vec_to_u32,
};

pub struct Stack<
    let MAX_STACK_ELEMENT_SIZE: u32, 
    let MAX_STACK_SIZE: u32,
    let CURRENT_TRANSACTION_SIZE: u32,
    let CURRENT_INPUT_COUNT: u32,
    let CURRENT_INPUT_SIZE: u32,
    let CURRENT_OUTPUT_COUNT: u32,
    let CURRENT_OUTPUT_SIZE: u32,
    let CURRENT_MAX_WITNESS_STACK_SIZE: u32,
    let CURRENT_WITNESS_SIZE: u32,
> {
    data: [BoundedVec<u8, MAX_STACK_ELEMENT_SIZE>; MAX_STACK_SIZE],
    stack_size: u32,
    alt_data: [BoundedVec<u8, MAX_STACK_ELEMENT_SIZE>; MAX_STACK_SIZE],
    alt_stack_size: u32,
    cur_transaction: Transaction<
        CURRENT_TRANSACTION_SIZE,
        CURRENT_INPUT_COUNT,
        CURRENT_INPUT_SIZE,
        CURRENT_OUTPUT_COUNT,
        CURRENT_OUTPUT_SIZE,
        CURRENT_MAX_WITNESS_STACK_SIZE,
        CURRENT_WITNESS_SIZE,
    >,
}

impl<
    let MAX_STACK_ELEMENT_SIZE: u32, 
    let MAX_STACK_SIZE: u32,
    let CURRENT_TRANSACTION_SIZE: u32,
    let CURRENT_INPUT_COUNT: u32,
    let CURRENT_INPUT_SIZE: u32,
    let CURRENT_OUTPUT_COUNT: u32,
    let CURRENT_OUTPUT_SIZE: u32,
    let CURRENT_MAX_WITNESS_STACK_SIZE: u32,
    let CURRENT_WITNESS_SIZE: u32,
> Stack<
    MAX_STACK_ELEMENT_SIZE,
    MAX_STACK_SIZE,
    CURRENT_TRANSACTION_SIZE,
    CURRENT_INPUT_COUNT,
    CURRENT_INPUT_SIZE,
    CURRENT_OUTPUT_COUNT,
    CURRENT_OUTPUT_SIZE,
    CURRENT_MAX_WITNESS_STACK_SIZE,
    CURRENT_WITNESS_SIZE,
> {
    pub fn new(
        cur_transaction: Transaction<
            CURRENT_TRANSACTION_SIZE,
            CURRENT_INPUT_COUNT,
            CURRENT_INPUT_SIZE,
            CURRENT_OUTPUT_COUNT,
            CURRENT_OUTPUT_SIZE,
            CURRENT_MAX_WITNESS_STACK_SIZE,
            CURRENT_WITNESS_SIZE,
        >
    ) -> Self {
        Stack {
            data: [BoundedVec::new(); MAX_STACK_SIZE],
            stack_size: 0,
            alt_data: [BoundedVec::new(); MAX_STACK_SIZE],
            alt_stack_size: 0,
            cur_transaction: cur_transaction,
        }
    }

    pub fn new_test_stack() -> Self {
        Stack {
            data: [BoundedVec::new(); MAX_STACK_SIZE],
            stack_size: 0,
            alt_data: [BoundedVec::new(); MAX_STACK_SIZE],
            alt_stack_size: 0,
            cur_transaction: Transaction::new_empty_transaction(),
        }
    }

    fn push(&mut self, value: BoundedVec<u8, MAX_STACK_ELEMENT_SIZE>) {
        self.data[self.stack_size] = value;
        self.stack_size += 1;
    }

    fn pop(&mut self) -> BoundedVec<u8, MAX_STACK_ELEMENT_SIZE> {
        assert(self.stack_size > 0);
        self.stack_size -= 1;
        self.data[self.stack_size]
    }

    // OP_0 ... OP_16
    pub fn op_num(&mut self, num: u8) {
        assert(num >= 0 & num <= 16);
        let byte_value: [u8; 1] = [num];
        let value = bytes_to_vec(byte_value);
        self.push(value);
    }

    pub fn op_pushbytes<let N: u32>(&mut self, input: [u8; N]) {
        let value = bytes_to_vec(input);
        self.push(value);
    }

    pub fn op_equal(&mut self) {
        let value1 = self.pop().storage();
        let value2 = self.pop().storage();
        if value1 == value2 {
            self.push(bytes_to_vec([1]));
        } else {
            self.push(bytes_to_vec([0]));
        }
    }

    pub fn op_add(&mut self) {
        let value1 = self.pop();
        let value2 = self.pop();

        let value3 = vec_to_i32(value1) + vec_to_i32(value2);
        self.push(i32_to_vec(value3));
    }

    pub fn verify(&mut self) -> bool {
        if self.data.len() == 0 {
            false
        } else {
            // TODO: check that top item is not 0
            // Not sure 0x00000000, for example, is valid or not
            true
        }
    }

    pub fn op_ifdup(&mut self) {
        let dup = self.data[self.stack_size - 1];
        if vec_to_i32(dup) != 0 {
            self.push(dup);
        }
    }

    pub fn op_fromaltstack(&mut self) {
        assert(self.alt_stack_size > 0);
        self.alt_stack_size -= 1;
        self.push(self.alt_data[self.alt_stack_size]);
    }

    pub fn op_toaltstack(&mut self) {
        let elem = self.pop();
        self.alt_data[self.alt_stack_size] = elem;
        self.alt_stack_size += 1;
    }

    pub fn op_depth(&mut self) {
        self.push(bytes_to_vec(u32_to_le_bytes(self.stack_size)));
    }

    pub fn op_drop(&mut self) {
        self.stack_size -= 1;
    }

    pub fn op_dup(&mut self) {
        self.push(self.data[self.stack_size - 1]);
    }

    pub fn op_nip(&mut self) {
        self.stack_size -= 1;
        self.data[self.stack_size - 1] = self.data[self.stack_size];
    }

    pub fn op_over(&mut self) {
        let dup = self.data[self.stack_size - 2];
        self.push(dup);
    }

    // !remove last element
    pub fn op_pick(&mut self) {
        let mut n = vec_to_u32(self.data[self.stack_size - 1]);
        assert(n < self.stack_size - 1);
        n = self.stack_size - n - 2;
        self.data[self.stack_size - 1] = self.data[n];
    }

    // !remove last element
    pub fn op_roll(&mut self) {
        let mut n = vec_to_u32(self.pop());
        assert(n < self.stack_size);
        n = self.stack_size - n - 1;
        let roll = self.data[n];
        for i in 0..MAX_STACK_SIZE {
            if i >= self.stack_size {
                // continue
            } else if i == self.stack_size - 1 {
                self.data[i] = roll;
            } else if i >= n {
                self.data[i] = self.data[i + 1];
            }
        }
    }

    pub fn op_rot(&mut self) {
        self.op_num(2);
        self.op_roll();
    }

    pub fn op_swap(&mut self) {
        let swap = self.data[self.stack_size - 2];
        self.data[self.stack_size - 2] = self.data[self.stack_size - 1];
        self.data[self.stack_size - 1] = swap;
    }

    pub fn op_tuck(&mut self) {
        self.op_swap();
        self.op_over();
    }

    pub fn op_2drop(&mut self) {
        self.op_drop();
        self.op_drop();
    }

    pub fn op_2dup(&mut self) {
        self.op_over();
        self.op_over();
    }

    pub fn op_3dup(&mut self) {
        self.op_num(2);
        self.op_pick();
        self.op_num(2);
        self.op_pick();
        self.op_num(2);
        self.op_pick();
    }

    pub fn op_2over(&mut self) {
        self.op_num(3);
        self.op_pick();
        self.op_num(3);
        self.op_pick();
    }

    pub fn op_2rot(&mut self) {
        self.op_num(5);
        self.op_roll();
        self.op_num(5);
        self.op_roll();
    }

    pub fn op_2swap(&mut self) {
        self.op_num(3);
        self.op_roll();
        self.op_num(3);
        self.op_roll();
    }

    pub fn op_checksig<
        let TRANSACTION_SIZE: u32,
        let INPUT_COUNT: u32,
        let INPUT_SIZE: u32,
        let OUTPUT_COUNT: u32,
        let OUTPUT_SIZE: u32,
        let MAX_WITNESS_STACK_SIZE: u32,
        let WITNESS_SIZE: u32,
    >(&mut self, 
        cur_transaction: Transaction<
            TRANSACTION_SIZE,
            INPUT_COUNT,
            INPUT_SIZE,
            OUTPUT_COUNT,
            OUTPUT_SIZE,
            MAX_WITNESS_STACK_SIZE,
            WITNESS_SIZE,
        >
    ) {
        let mut sig = self.pop();
        let mut pubkey = self.pop();

        let sig_bytes = sig.storage();
        let pubkey_bytes = pubkey.storage();
    }
}

#[test]
fn test_addition() {
    let mut stack = Stack::<10, 4, 0, 0, 0, 0, 0, 0, 0>::new_test_stack();

    let a = 12345;
    let b = 4648;
    let c = a + b;

    let a_bytes = i32_to_le_bytes(a);
    let b_bytes = i32_to_le_bytes(b);
    let c_bytes = i32_to_le_bytes(c);

    stack.op_pushbytes(a_bytes);
    stack.op_pushbytes(b_bytes);
    stack.op_add();
    stack.op_pushbytes(c_bytes);

    stack.op_equal();

    assert(vec_to_i32(stack.pop()) == 1);
}

#[test]
fn test_op_num() {
    let mut stack = Stack::<10, 4, 0, 0, 0, 0, 0, 0, 0>::new_test_stack();
    stack.op_num(2);
    stack.op_num(5);
    stack.op_add();
    stack.op_num(3);
    stack.op_add();
    stack.op_num(10);

    stack.op_equal();

    let bool_vec = stack.pop();
    let bool_value = vec_to_i32(bool_vec);

    assert(bool_value == 1);
}

#[test]
fn test_dups() {
    let mut stack = Stack::<10, 6, 0, 0, 0, 0, 0, 0, 0>::new_test_stack();
    stack.op_num(2);
    stack.op_ifdup();
    assert(stack.stack_size == 2);
    stack.op_num(0);
    stack.op_ifdup();
    assert(stack.stack_size == 3);
    stack.op_dup();
    assert(stack.stack_size == 4);

    stack.op_equal();
    assert(vec_to_i32(stack.pop()) == 1);
    stack.op_equal();
    assert(vec_to_i32(stack.pop()) == 1);

    stack.op_num(2);
    stack.op_num(3);
    stack.op_2dup();
    assert(vec_to_i32(stack.pop()) == 3);
    stack.op_3dup();
    assert(vec_to_i32(stack.pop()) == 2);
    assert(vec_to_i32(stack.pop()) == 3);
    assert(vec_to_i32(stack.pop()) == 2);
    assert(vec_to_i32(stack.pop()) == 2);
    assert(vec_to_i32(stack.pop()) == 3);
    assert(vec_to_i32(stack.pop()) == 2);
}

#[test]
fn test_alt_stack() {
    let mut stack = Stack::<10, 4, 0, 0, 0, 0, 0, 0, 0>::new_test_stack();
    stack.op_num(2);
    stack.op_toaltstack();
    assert(stack.stack_size == 0);
    assert(stack.alt_stack_size == 1);
    stack.op_fromaltstack();
    assert(stack.stack_size == 1);
    assert(stack.alt_stack_size == 0);
}

#[test]
fn test_depth_drops() {
    let mut stack = Stack::<10, 4, 0, 0, 0, 0, 0, 0, 0>::new_test_stack();
    stack.op_num(2);
    stack.op_num(5);
    stack.op_depth();
    assert(vec_to_u32(stack.pop()) == 2);
    stack.op_2drop();
    stack.op_depth();
    assert(vec_to_u32(stack.pop()) == 0);
}

#[test]
fn test_nip_overs() {
    let mut stack = Stack::<10, 6, 0, 0, 0, 0, 0, 0, 0>::new_test_stack();
    stack.op_num(2);
    stack.op_num(5);
    stack.op_over();
    stack.op_nip();
    stack.op_equal();
    assert(vec_to_i32(stack.pop()) == 1);

    stack.op_num(3);
    stack.op_num(4);
    stack.op_num(1);
    stack.op_num(2);
    stack.op_2over();
    assert(vec_to_i32(stack.pop()) == 4);
    assert(vec_to_i32(stack.pop()) == 3);
    assert(vec_to_i32(stack.pop()) == 2);
    assert(vec_to_i32(stack.pop()) == 1);
    assert(vec_to_i32(stack.pop()) == 4);
    assert(vec_to_i32(stack.pop()) == 3);
}

#[test]
fn test_pick() {
    let mut stack = Stack::<10, 4, 0, 0, 0, 0, 0, 0, 0>::new_test_stack();
    stack.op_num(2);
    stack.op_num(5);
    stack.op_num(3);
    stack.op_num(1);
    stack.op_pick();
    assert(vec_to_u32(stack.pop()) == 5);
}

#[test]
fn test_roll() {
    let mut stack = Stack::<10, 4, 0, 0, 0, 0, 0, 0, 0>::new_test_stack();
    stack.op_num(2);
    stack.op_num(5);
    stack.op_num(3);
    stack.op_num(2);
    stack.op_roll();
    assert(vec_to_u32(stack.pop()) == 2);
}

#[test]
fn test_swaps() {
    let mut stack = Stack::<10, 5, 0, 0, 0, 0, 0, 0, 0>::new_test_stack();
    stack.op_num(2);
    stack.op_num(5);
    stack.op_swap();
    assert(vec_to_u32(stack.pop()) == 2);

    stack.op_num(2);
    stack.op_num(5);
    stack.op_num(3);
    stack.op_2swap();
    assert(vec_to_u32(stack.pop()) == 2);
    assert(vec_to_u32(stack.pop()) == 5);
    assert(vec_to_u32(stack.pop()) == 3);
    assert(vec_to_u32(stack.pop()) == 5);
}

#[test]
fn test_tuck() {
    let mut stack = Stack::<10, 5, 0, 0, 0, 0, 0, 0, 0>::new_test_stack();
    stack.op_num(2);
    stack.op_num(5);
    stack.op_tuck();
    assert(vec_to_u32(stack.pop()) == 5);
    assert(vec_to_u32(stack.pop()) == 2);
    assert(vec_to_u32(stack.pop()) == 5);
}

#[test]
fn test_rots() {
    let mut stack = Stack::<10, 7, 0, 0, 0, 0, 0, 0, 0>::new_test_stack();
    stack.op_num(1);
    stack.op_num(2);
    stack.op_num(3);
    stack.op_rot();
    assert(vec_to_u32(stack.pop()) == 1);
    assert(vec_to_u32(stack.pop()) == 3);
    assert(vec_to_u32(stack.pop()) == 2);

    stack.op_num(1);
    stack.op_num(2);
    stack.op_num(3);
    stack.op_num(4);
    stack.op_num(5);
    stack.op_num(6);
    stack.op_2rot();
    assert(vec_to_u32(stack.pop()) == 2);
    assert(vec_to_u32(stack.pop()) == 1);
    assert(vec_to_u32(stack.pop()) == 6);
    assert(vec_to_u32(stack.pop()) == 5);
    assert(vec_to_u32(stack.pop()) == 4);
    assert(vec_to_u32(stack.pop()) == 3);
}

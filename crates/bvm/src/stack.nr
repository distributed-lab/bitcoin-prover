use crate::utils::split_raw_signature;
use dep::bignum::{BigNum, U768};
use ripemd160::ripemd160;
use sha1::sha1;
use sign::{legacy::serialize_sighash_all, transaction::Transaction};
use std::{collections::bounded_vec::BoundedVec, ecdsa_secp256k1, ops::{Add, Mul}};

use crypto::{ecdsa::ecdsa_verify, point::get_y_from_x, types::{I768, sqrt_secp256k1}, point::get_low_s_if_needed};
use utils::{
    convert::{
        bytes_to_hex, bytes_to_vec, cut_array, get_256_bits_from_768, hex_to_bytes, i32_to_le_bytes,
        i32_to_vec, reverse_bytes, u32_to_le_bytes, vec_to_array, vec_to_i32, vec_to_u32,
    },
};

pub struct Stack<let MAX_STACK_ELEMENT_SIZE: u32, let MAX_STACK_SIZE: u32, let CURRENT_TRANSACTION_SIZE: u32, let CURRENT_INPUT_COUNT: u32, let CURRENT_INPUT_SIZE: u32, let CURRENT_OUTPUT_COUNT: u32, let CURRENT_OUTPUT_SIZE: u32, let CURRENT_MAX_WITNESS_STACK_SIZE: u32, let CURRENT_WITNESS_SIZE: u32> {
    data: [BoundedVec<u8, MAX_STACK_ELEMENT_SIZE>; MAX_STACK_SIZE],
    stack_size: u32,
    alt_data: [BoundedVec<u8, MAX_STACK_ELEMENT_SIZE>; MAX_STACK_SIZE],
    alt_stack_size: u32,
    cur_transaction: Transaction<CURRENT_TRANSACTION_SIZE, CURRENT_INPUT_COUNT, CURRENT_INPUT_SIZE, CURRENT_OUTPUT_COUNT, CURRENT_OUTPUT_SIZE, CURRENT_MAX_WITNESS_STACK_SIZE, CURRENT_WITNESS_SIZE>,
}

impl<let MAX_STACK_ELEMENT_SIZE: u32, let MAX_STACK_SIZE: u32, let CURRENT_TRANSACTION_SIZE: u32, let CURRENT_INPUT_COUNT: u32, let CURRENT_INPUT_SIZE: u32, let CURRENT_OUTPUT_COUNT: u32, let CURRENT_OUTPUT_SIZE: u32, let CURRENT_MAX_WITNESS_STACK_SIZE: u32, let CURRENT_WITNESS_SIZE: u32> Stack<MAX_STACK_ELEMENT_SIZE, MAX_STACK_SIZE, CURRENT_TRANSACTION_SIZE, CURRENT_INPUT_COUNT, CURRENT_INPUT_SIZE, CURRENT_OUTPUT_COUNT, CURRENT_OUTPUT_SIZE, CURRENT_MAX_WITNESS_STACK_SIZE, CURRENT_WITNESS_SIZE> {
    pub fn new(
        cur_transaction: Transaction<CURRENT_TRANSACTION_SIZE, CURRENT_INPUT_COUNT, CURRENT_INPUT_SIZE, CURRENT_OUTPUT_COUNT, CURRENT_OUTPUT_SIZE, CURRENT_MAX_WITNESS_STACK_SIZE, CURRENT_WITNESS_SIZE>,
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
    pub fn op_num(&mut self, num: i8) {
        assert(num >= -1 & num <= 16);
        self.push(i32_to_vec(num as i32));
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

    pub fn op_sub(&mut self) {
        let value1 = self.pop();
        let value2 = self.pop();

        let value3 = vec_to_i32(value2) - vec_to_i32(value1);
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

    pub fn op_1add(&mut self) {
        let num = vec_to_i32(self.data[self.stack_size - 1]);
        self.data[self.stack_size - 1] = i32_to_vec(num + 1);
    }

    pub fn op_1sub(&mut self) {
        let num = vec_to_i32(self.data[self.stack_size - 1]);
        self.data[self.stack_size - 1] = i32_to_vec(num - 1);
    }

    pub fn op_negate(&mut self) {
        let num = vec_to_i32(self.data[self.stack_size - 1]);
        self.data[self.stack_size - 1] = i32_to_vec(-num);
    }

    pub fn op_abs(&mut self) {
        let mut num = vec_to_i32(self.data[self.stack_size - 1]);
        if num < 0 {
            num = -num;
        }
        self.data[self.stack_size - 1] = i32_to_vec(num);
    }

    pub fn op_not(&mut self) {
        let mut num = vec_to_i32(self.data[self.stack_size - 1]);
        if num == 0 {
            num = 1;
        } else {
            num = 0;
        }
        self.data[self.stack_size - 1] = i32_to_vec(num);
    }

    pub fn op_0notequal(&mut self) {
        let mut num = vec_to_i32(self.data[self.stack_size - 1]);
        if num != 0 {
            num = 1;
        }
        self.data[self.stack_size - 1] = i32_to_vec(num);
    }

    pub fn op_booland(&mut self) {
        let value1 = vec_to_i32(self.pop());
        let value2 = vec_to_i32(self.pop());

        if (value1 != 0) & (value2 != 0) {
            self.push(i32_to_vec(1));
        } else {
            self.push(i32_to_vec(0));
        }
    }

    pub fn op_boolor(&mut self) {
        let value1 = vec_to_i32(self.pop());
        let value2 = vec_to_i32(self.pop());

        if (value1 != 0) | (value2 != 0) {
            self.push(i32_to_vec(1));
        } else {
            self.push(i32_to_vec(0));
        }
    }

    pub fn op_numequal(&mut self) {
        let value1 = vec_to_i32(self.pop());
        let value2 = vec_to_i32(self.pop());

        if value1 == value2 {
            self.push(i32_to_vec(1));
        } else {
            self.push(i32_to_vec(0));
        }
    }

    pub fn op_numnotequal(&mut self) {
        let value1 = vec_to_i32(self.pop());
        let value2 = vec_to_i32(self.pop());

        if value1 != value2 {
            self.push(i32_to_vec(1));
        } else {
            self.push(i32_to_vec(0));
        }
    }

    pub fn op_lessthan(&mut self) {
        let value1 = vec_to_i32(self.pop());
        let value2 = vec_to_i32(self.pop());

        if value1 > value2 {
            self.push(i32_to_vec(1));
        } else {
            self.push(i32_to_vec(0));
        }
    }

    pub fn op_greaterthan(&mut self) {
        let value1 = vec_to_i32(self.pop());
        let value2 = vec_to_i32(self.pop());

        if value1 < value2 {
            self.push(i32_to_vec(1));
        } else {
            self.push(i32_to_vec(0));
        }
    }

    pub fn op_lessthanorequal(&mut self) {
        let value1 = vec_to_i32(self.pop());
        let value2 = vec_to_i32(self.pop());

        if value1 >= value2 {
            self.push(i32_to_vec(1));
        } else {
            self.push(i32_to_vec(0));
        }
    }

    pub fn op_greaterthanorequal(&mut self) {
        let value1 = vec_to_i32(self.pop());
        let value2 = vec_to_i32(self.pop());

        if value1 <= value2 {
            self.push(i32_to_vec(1));
        } else {
            self.push(i32_to_vec(0));
        }
    }

    pub fn op_min(&mut self) {
        let value1 = vec_to_i32(self.pop());
        let value2 = vec_to_i32(self.pop());

        if value1 > value2 {
            self.push(i32_to_vec(value2));
        } else {
            self.push(i32_to_vec(value1));
        }
    }

    pub fn op_max(&mut self) {
        let value1 = vec_to_i32(self.pop());
        let value2 = vec_to_i32(self.pop());

        if value1 > value2 {
            self.push(i32_to_vec(value1));
        } else {
            self.push(i32_to_vec(value2));
        }
    }

    // !not sure about arguments order
    pub fn op_within(&mut self) {
        let max = vec_to_i32(self.pop());
        let min = vec_to_i32(self.pop());
        let x = vec_to_i32(self.pop());

        if (x >= min) & (x < max) {
            self.push(i32_to_vec(1));
        } else {
            self.push(i32_to_vec(0));
        }
    }

    pub fn op_ripemd160<let LEN: u32>(&mut self) {
        let hash = ripemd160(
            cut_array::<MAX_STACK_ELEMENT_SIZE, LEN>(self.pop().storage()),
        );
        let mut vec = BoundedVec::new();
        vec.extend_from_slice(hash);
        self.push(vec);
    }

    pub fn op_sha1<let LEN: u32>(&mut self) {
        let hash = sha1::digest(
            cut_array::<MAX_STACK_ELEMENT_SIZE, LEN>(self.pop().storage()),
        );
        let mut vec = BoundedVec::new();
        vec.extend_from_slice(hash);
        self.push(vec);
    }

    pub fn op_sha256<let LEN: u32>(&mut self) {
        let hash = sha256::digest(
            cut_array::<MAX_STACK_ELEMENT_SIZE, LEN>(self.pop().storage()),
        );
        let mut vec = BoundedVec::new();
        vec.extend_from_slice(hash);
        self.push(vec);
    }

    pub fn op_hash160<let LEN: u32>(&mut self) {
        let hash = sha256::digest(
            cut_array::<MAX_STACK_ELEMENT_SIZE, LEN>(self.pop().storage()),
        );
        let dhash = ripemd160(hash);
        let mut vec = BoundedVec::new();
        vec.extend_from_slice(dhash);
        self.push(vec);
    }

    pub fn op_hash256<let LEN: u32>(&mut self) {
        let hash = sha256::digest(
            cut_array::<MAX_STACK_ELEMENT_SIZE, LEN>(self.pop().storage()),
        );
        let dhash = sha256::digest(hash);
        let mut vec = BoundedVec::new();
        vec.extend_from_slice(dhash);
        self.push(vec);
    }

    // todo: implement this opcode
    pub fn op_codeseparator(&mut self) {
        //
    }

    // todo: implement this opcode
    pub fn op_size() {
        //
    }

    pub fn op_checksig_sighash_all<
        let SIGNATURE_LEN: u32,
        let SCRIPT_PUB_KEY_LEN: u32,
        let PUBKEY_LEN: u32,
    >(
        &mut self,
        input_to_sign: u32,
        script_pub_key: [u8; SCRIPT_PUB_KEY_LEN],
    ) -> bool {
        let mut pubkey_vec = self.pop();
        let mut raw_signature_vec = self.pop();

        let signature_bytes = vec_to_array::<MAX_STACK_ELEMENT_SIZE, SIGNATURE_LEN>(raw_signature_vec);
        let (encoded_signature, hash_type) = split_raw_signature(signature_bytes);
        assert(hash_type == 0x01);

        let mut pubkey_bytes = vec_to_array::<MAX_STACK_ELEMENT_SIZE, PUBKEY_LEN>(pubkey_vec);

        let message_hash = serialize_sighash_all(self.cur_transaction, input_to_sign, script_pub_key);

        ecdsa_verify(encoded_signature, pubkey_bytes, message_hash)
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

    stack.op_num(-1);
    assert(vec_to_i32(stack.pop()) == -1);
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

#[test]
fn test_ripemd160() {
    let mut stack = Stack::<20, 7, 0, 0, 0, 0, 0, 0, 0>::new_test_stack();
    stack.op_num(1);
    stack.op_ripemd160::<1>();
    assert(
        stack.pop().storage()
            == [
                0xf2, 0x91, 0xba, 0x50, 0x15, 0xdf, 0x34, 0x8c, 0x80, 0x85, 0x3f, 0xa5, 0xbb, 0x0f,
                0x79, 0x46, 0xf5, 0xc9, 0xe1, 0xb3,
            ],
    );
}

#[test]
fn test_sha1() {
    let mut stack = Stack::<20, 7, 0, 0, 0, 0, 0, 0, 0>::new_test_stack();
    stack.op_num(1);
    stack.op_sha1::<1>();
    assert(
        stack.pop().storage()
            == [
                0xbf, 0x8b, 0x45, 0x30, 0xd8, 0xd2, 0x46, 0xdd, 0x74, 0xac, 0x53, 0xa1, 0x34, 0x71,
                0xbb, 0xa1, 0x79, 0x41, 0xdf, 0xf7,
            ],
    );
}

#[test]
fn test_sha256() {
    let mut stack = Stack::<32, 7, 0, 0, 0, 0, 0, 0, 0>::new_test_stack();
    stack.op_num(1);
    stack.op_sha256::<1>();
    assert(
        stack.pop().storage()
            == [
                0x4b, 0xf5, 0x12, 0x2f, 0x34, 0x45, 0x54, 0xc5, 0x3b, 0xde, 0x2e, 0xbb, 0x8c, 0xd2,
                0xb7, 0xe3, 0xd1, 0x60, 0x0a, 0xd6, 0x31, 0xc3, 0x85, 0xa5, 0xd7, 0xcc, 0xe2, 0x3c,
                0x77, 0x85, 0x45, 0x9a,
            ],
    );
}

#[test]
fn test_hash160() {
    let mut stack = Stack::<20, 7, 0, 0, 0, 0, 0, 0, 0>::new_test_stack();
    stack.op_num(1);
    stack.op_hash160::<1>();
    assert(
        stack.pop().storage()
            == [
                0xc5, 0x1b, 0x66, 0xbc, 0xed, 0x5e, 0x44, 0x91, 0x00, 0x1b, 0xd7, 0x02, 0x66, 0x97,
                0x70, 0xdc, 0xcf, 0x44, 0x09, 0x82,
            ],
    );
}

#[test]
fn test_hash256() {
    let mut stack = Stack::<32, 7, 0, 0, 0, 0, 0, 0, 0>::new_test_stack();
    stack.op_num(1);
    stack.op_hash256::<1>();
    assert(
        stack.pop().storage()
            == [
                0x9c, 0x12, 0xcf, 0xdc, 0x04, 0xc7, 0x45, 0x84, 0xd7, 0x87, 0xac, 0x3d, 0x23, 0x77,
                0x21, 0x32, 0xc1, 0x85, 0x24, 0xbc, 0x7a, 0xb2, 0x8d, 0xec, 0x42, 0x19, 0xb8, 0xfc,
                0x5b, 0x42, 0x5f, 0x70,
            ],
    );
}

#[test]
fn test_arithmetic() {
    let mut stack = Stack::<5, 7, 0, 0, 0, 0, 0, 0, 0>::new_test_stack();
    stack.op_num(10);
    stack.op_num(2);
    stack.op_sub();
    stack.op_1add();
    stack.op_negate();
    stack.op_1sub();
    stack.op_dup();
    stack.op_dup();
    assert(vec_to_i32(stack.pop()) == -10);
    stack.op_abs();
    assert(vec_to_i32(stack.pop()) == 10);
    stack.op_0notequal();
    assert(vec_to_i32(stack.pop()) == 1);
}

#[test]
fn test_logical() {
    let mut stack = Stack::<5, 7, 0, 0, 0, 0, 0, 0, 0>::new_test_stack();
    stack.op_num(10);
    stack.op_num(0);
    stack.op_2dup();
    stack.op_booland();
    assert(vec_to_i32(stack.pop()) == 0);
    stack.op_boolor();
    stack.op_not();
    assert(vec_to_i32(stack.pop()) == 0);

    stack.op_num(10);
    stack.op_num(10);
    stack.op_2dup();
    stack.op_numequal();
    assert(vec_to_i32(stack.pop()) == 1);
    stack.op_numnotequal();
    assert(vec_to_i32(stack.pop()) == 0);

    stack.op_num(10);
    stack.op_num(13);
    stack.op_num(13);
    stack.op_num(10);
    stack.op_greaterthan();
    stack.op_toaltstack();
    stack.op_lessthan();
    stack.op_fromaltstack();
    stack.op_equal();
    assert(vec_to_i32(stack.pop()) == 1);

    stack.op_num(10);
    stack.op_num(10);
    stack.op_num(12);
    stack.op_num(10);
    stack.op_greaterthanorequal();
    stack.op_toaltstack();
    stack.op_lessthanorequal();
    stack.op_fromaltstack();
    stack.op_equal();
    assert(vec_to_i32(stack.pop()) == 1);
}

#[test]
fn test_max_min_range() {
    let mut stack = Stack::<5, 7, 0, 0, 0, 0, 0, 0, 0>::new_test_stack();
    stack.op_num(10);
    stack.op_num(12);
    stack.op_max();
    assert(vec_to_i32(stack.pop()) == 12);

    stack.op_num(10);
    stack.op_num(12);
    stack.op_min();
    assert(vec_to_i32(stack.pop()) == 10);

    stack.op_num(10);
    stack.op_num(10);
    stack.op_num(15);
    stack.op_within();
    assert(vec_to_i32(stack.pop()) == 1);
}

#[test]
fn test_checksig() {
    // From here: https://www.blockchain.com/explorer/transactions/btc/12e753ef5cc30925a6eee2c457aa7f53022443ca013ea81882a6b59b69e342a6
    // Transaction with deleted script sigs
    let cur_tx_hex: str<402> = "01000000030dd7891efbf67da47c651531db8aab3144ed7a524e4ae1e30b773525e27ddd7b0000000000ffffffff16851666962e37a75a246101f2e340c628b1db3c045d4d3cfb2d1c0f58f97c6f0000000000ffffffffffda5d38e91fd9a0d92872d51f83cb746fc7bf5d3ff13402f8d0d5ed60ddc79c0000000000ffffffff02c0c62d00000000001976a91417194e1bd175fb5b1b2a1f9d221f6f5c29e1928388ac00c817a8040000001976a91465bda9b05f7e9a8f96a7f4ba0996a877708ef90888ac00000000";
    let cur_tx_bytes = hex_to_bytes(cur_tx_hex);
    let cur_tx = Transaction::<201, 3, 124, 2, 69, 0, 0>::new(cur_tx_bytes, false);

    let input_to_sign = 1;

    let mut stack = Stack::<80, 7, 201, 3, 124, 2, 69, 0, 0>::new(cur_tx);

    let signature_hex: str<144> = "304502203f004eeed0cef2715643e2f25a27a28f3c578e94c7f0f6a4df104e7d163f7f8f022100b8b248c1cfd8f77a0365107a9511d759b7544d979dd152a955c867afac0ef78601";
    let signature_bytes = hex_to_bytes(signature_hex);

    // From here: https://www.blockchain.com/explorer/transactions/btc/6f7cf9580f1c2dfb3c4d5d043cdbb128c640e3f20161245aa7372e9666168516
    // script_pub_key includes the length of the script
    let script_pub_key_hex: str<52> = "1976a91412ab8dc588ca9d5787dde7eb29569da63c3a238c88ac";
    let script_pub_key_bytes = hex_to_bytes(script_pub_key_hex);

    let pubkey_hex: str<130> = "044d05240cfbd8a2786eda9dadd520c1609b8593ff8641018d57703d02ba687cf2f187f0cee2221c3afb1b5ff7888caced2423916b61444666ca1216f26181398c";
    let pubkey_bytes = hex_to_bytes(pubkey_hex);

    stack.push(bytes_to_vec(signature_bytes));
    stack.push(bytes_to_vec(pubkey_bytes));

    assert(stack.op_checksig_sighash_all::<72, 26, 65>(input_to_sign, script_pub_key_bytes));
}

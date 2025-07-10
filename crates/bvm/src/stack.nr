use bignum::{BigNum, fields::{U256::U256, U768::U768}};
use crypto::{
    ecdsa::{
        ecdsa_verify, get_rs_from_signature, get_xy_from_compressed_pubkey,
        get_xy_from_uncompressed_pubkey,
    },
    types::I768,
};
use ripemd160::ripemd160;
use sha1::sha1;
use sign::address::Address;
use sign::{
    legacy::serialize_sighash_all, segwit::serialize_p2wpkh_sighash_all, transaction::Transaction,
};
use sign::sig_types::{SIGHASH_ALL, SIGHASH_ANYONECANPAY, SIGHASH_NONE, SIGHASH_SINGLE};
use std::collections::bounded_vec::BoundedVec;
use utils::convert::{
    bytes_to_hex, bytes_to_vec, get_256_bits_from_768, hex_to_bytes, i32_to_le_bytes, i32_to_vec,
    u32_to_le_bytes, vec_to_array, vec_to_i32, vec_to_u32,
};

pub fn empty_stack_array<let MAX_STACK_ELEMENT_SIZE: u32, let MAX_STACK_SIZE: u32>() -> [BoundedVec<u8, MAX_STACK_ELEMENT_SIZE>; MAX_STACK_SIZE] {
    [BoundedVec::new(); MAX_STACK_SIZE]
}

pub struct Stack<let MAX_STACK_ELEMENT_SIZE: u32, let MAX_STACK_SIZE: u32, let CURRENT_TRANSACTION_SIZE: u32, let CURRENT_INPUT_COUNT: u32, let CURRENT_INPUT_COUNT_LEN: u32, let CURRENT_INPUT_SIZE: u32, let CURRENT_OUTPUT_COUNT: u32, let CURRENT_OUTPUT_COUNT_LEN: u32, let CURRENT_OUTPUT_SIZE: u32, let CURRENT_MAX_WITNESS_STACK_SIZE: u32, let CURRENT_WITNESS_SIZE: u32, let PREV_TRANSACTION_SIZE: u32, let PREV_INPUT_COUNT: u32, let PREV_INPUT_COUNT_LEN: u32, let PREV_INPUT_SIZE: u32, let PREV_OUTPUT_COUNT: u32, let PREV_OUTPUT_COUNT_LEN: u32, let PREV_OUTPUT_SIZE: u32, let PREV_MAX_WITNESS_STACK_SIZE: u32, let PREV_WITNESS_SIZE: u32> {
    data: [BoundedVec<u8, MAX_STACK_ELEMENT_SIZE>; MAX_STACK_SIZE],
    stack_size: u32,
    alt_data: [BoundedVec<u8, MAX_STACK_ELEMENT_SIZE>; MAX_STACK_SIZE],
    alt_stack_size: u32,
    cur_transaction: Transaction<CURRENT_TRANSACTION_SIZE, CURRENT_INPUT_COUNT, CURRENT_INPUT_COUNT_LEN, CURRENT_INPUT_SIZE, CURRENT_OUTPUT_COUNT, CURRENT_OUTPUT_COUNT_LEN, CURRENT_OUTPUT_SIZE, CURRENT_MAX_WITNESS_STACK_SIZE, CURRENT_WITNESS_SIZE>,
    prev_transaction: Transaction<PREV_TRANSACTION_SIZE, PREV_INPUT_COUNT, PREV_INPUT_COUNT_LEN, PREV_INPUT_SIZE, PREV_OUTPUT_COUNT, PREV_OUTPUT_COUNT_LEN, PREV_OUTPUT_SIZE, PREV_MAX_WITNESS_STACK_SIZE, PREV_WITNESS_SIZE>,
    input_to_sign: u32,
    output_to_unlock: u32,
}

impl<let MAX_STACK_ELEMENT_SIZE: u32, let MAX_STACK_SIZE: u32> Stack<MAX_STACK_ELEMENT_SIZE, MAX_STACK_SIZE, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0> {
    pub fn new_test_stack() -> Stack<MAX_STACK_ELEMENT_SIZE, MAX_STACK_SIZE, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0> {
        Self {
            data: [BoundedVec::new(); MAX_STACK_SIZE],
            stack_size: 0,
            alt_data: [BoundedVec::new(); MAX_STACK_SIZE],
            alt_stack_size: 0,
            cur_transaction: Transaction::<0, 0, 0, 0, 0, 0, 0, 0, 0>::new_empty_transaction(),
            prev_transaction: Transaction::<0, 0, 0, 0, 0, 0, 0, 0, 0>::new_empty_transaction(),
            input_to_sign: 0,
            output_to_unlock: 0,
        }
    }
}

impl<let MAX_STACK_ELEMENT_SIZE: u32, let MAX_STACK_SIZE: u32, let CURRENT_TRANSACTION_SIZE: u32, let CURRENT_INPUT_COUNT: u32, let CURRENT_INPUT_COUNT_LEN: u32, let CURRENT_INPUT_SIZE: u32, let CURRENT_OUTPUT_COUNT: u32, let CURRENT_OUTPUT_COUNT_LEN: u32, let CURRENT_OUTPUT_SIZE: u32, let CURRENT_MAX_WITNESS_STACK_SIZE: u32, let CURRENT_WITNESS_SIZE: u32, let PREV_TRANSACTION_SIZE: u32, let PREV_INPUT_COUNT: u32, let PREV_INPUT_COUNT_LEN: u32, let PREV_INPUT_SIZE: u32, let PREV_OUTPUT_COUNT: u32, let PREV_OUTPUT_COUNT_LEN: u32, let PREV_OUTPUT_SIZE: u32, let PREV_MAX_WITNESS_STACK_SIZE: u32, let PREV_WITNESS_SIZE: u32> Stack<MAX_STACK_ELEMENT_SIZE, MAX_STACK_SIZE, CURRENT_TRANSACTION_SIZE, CURRENT_INPUT_COUNT, CURRENT_INPUT_COUNT_LEN, CURRENT_INPUT_SIZE, CURRENT_OUTPUT_COUNT, CURRENT_OUTPUT_COUNT_LEN, CURRENT_OUTPUT_SIZE, CURRENT_MAX_WITNESS_STACK_SIZE, CURRENT_WITNESS_SIZE, PREV_TRANSACTION_SIZE, PREV_INPUT_COUNT, PREV_INPUT_COUNT_LEN, PREV_INPUT_SIZE, PREV_OUTPUT_COUNT, PREV_OUTPUT_COUNT_LEN, PREV_OUTPUT_SIZE, PREV_MAX_WITNESS_STACK_SIZE, PREV_WITNESS_SIZE> {
    pub fn new(
        cur_transaction: Transaction<CURRENT_TRANSACTION_SIZE, CURRENT_INPUT_COUNT, CURRENT_INPUT_COUNT_LEN, CURRENT_INPUT_SIZE, CURRENT_OUTPUT_COUNT, CURRENT_OUTPUT_COUNT_LEN, CURRENT_OUTPUT_SIZE, CURRENT_MAX_WITNESS_STACK_SIZE, CURRENT_WITNESS_SIZE>,
        prev_transaction: Transaction<PREV_TRANSACTION_SIZE, PREV_INPUT_COUNT, PREV_INPUT_COUNT_LEN, PREV_INPUT_SIZE, PREV_OUTPUT_COUNT, PREV_OUTPUT_COUNT_LEN, PREV_OUTPUT_SIZE, PREV_MAX_WITNESS_STACK_SIZE, PREV_WITNESS_SIZE>,
        input_to_sign: u32,
        output_to_unlock: u32,
        stack_array: [BoundedVec<u8, MAX_STACK_ELEMENT_SIZE>; MAX_STACK_SIZE],
    ) -> Stack<MAX_STACK_ELEMENT_SIZE, MAX_STACK_SIZE, CURRENT_TRANSACTION_SIZE, CURRENT_INPUT_COUNT, CURRENT_INPUT_COUNT_LEN, CURRENT_INPUT_SIZE, CURRENT_OUTPUT_COUNT, CURRENT_OUTPUT_COUNT_LEN, CURRENT_OUTPUT_SIZE, CURRENT_MAX_WITNESS_STACK_SIZE, CURRENT_WITNESS_SIZE, PREV_TRANSACTION_SIZE, PREV_INPUT_COUNT, PREV_INPUT_COUNT_LEN, PREV_INPUT_SIZE, PREV_OUTPUT_COUNT, PREV_OUTPUT_COUNT_LEN, PREV_OUTPUT_SIZE, PREV_MAX_WITNESS_STACK_SIZE, PREV_WITNESS_SIZE> {
        Stack {
            data: stack_array,
            stack_size: 0,
            alt_data: stack_array,
            alt_stack_size: 0,
            cur_transaction: cur_transaction,
            prev_transaction: prev_transaction,
            input_to_sign: input_to_sign,
            output_to_unlock: output_to_unlock,
        }
    }

    fn push(&mut self, value: BoundedVec<u8, MAX_STACK_ELEMENT_SIZE>) {
        self.data[self.stack_size] = value;
        self.stack_size += 1;
    }

    pub fn push_bytes<let N: u32>(&mut self, input: [u8; N]) {
        let value = bytes_to_vec(input);
        self.push(value)
    }

    fn pop(&mut self) -> BoundedVec<u8, MAX_STACK_ELEMENT_SIZE> {
        assert(self.stack_size > 0);
        self.stack_size -= 1;
        self.data[self.stack_size]
    }

    pub fn pop_bytes<let N: u32>(&mut self) -> [u8; N] {
        let value = self.pop();
        // println(value);
        // println(value.len());
        // assert(value.len() == N);
        let mut value_array = [0; N];
        for i in 0..N {
            value_array[i] = value.storage()[i];
        }
        value_array
    }

    pub fn pop_pubkey(&mut self) -> ([u8; 32], [u8; 32]) {
        let pubkey_bytes = self.pop();

        if pubkey_bytes.len() == 33 {
            get_xy_from_compressed_pubkey(vec_to_array::<MAX_STACK_ELEMENT_SIZE, 33>(pubkey_bytes))
        } else if pubkey_bytes.len() == 65 {
            get_xy_from_uncompressed_pubkey(vec_to_array::<MAX_STACK_ELEMENT_SIZE, 65>(pubkey_bytes))
        } else {
            assert(false, "Invalid pubkey length");
            ([0; 32], [0; 32])
        }
    }

    pub fn pop_signature(&mut self) -> ([u8; 64], u8) {
        let encoded_signature_vec = self.pop();

        let mut signature = [0; 64];
        let mut hash_type = 0;

        if encoded_signature_vec.len() - 1 == 71 {
            let encoded_signature_with_hash_type =
                vec_to_array::<MAX_STACK_ELEMENT_SIZE, 72>(encoded_signature_vec);
            hash_type = encoded_signature_with_hash_type[71];
            let mut encoded_signature = [0; 71];
            for i in 0..71 {
                encoded_signature[i] = encoded_signature_with_hash_type[i];
            }
            signature = get_rs_from_signature(encoded_signature);
        } else if encoded_signature_vec.len() - 1 == 70 {
            let encoded_signature_with_hash_type =
                vec_to_array::<MAX_STACK_ELEMENT_SIZE, 71>(encoded_signature_vec);
            hash_type = encoded_signature_with_hash_type[70];
            let mut encoded_signature = [0; 70];
            for i in 0..70 {
                encoded_signature[i] = encoded_signature_with_hash_type[i];
            }
            signature = get_rs_from_signature(encoded_signature);
        } else if encoded_signature_vec.len() - 1 == 72 {
            let encoded_signature_with_hash_type =
                vec_to_array::<MAX_STACK_ELEMENT_SIZE, 73>(encoded_signature_vec);
            hash_type = encoded_signature_with_hash_type[72];
            let mut encoded_signature = [0; 72];
            for i in 0..72 {
                encoded_signature[i] = encoded_signature_with_hash_type[i];
            }
            signature = get_rs_from_signature(encoded_signature);
        } else {
            assert(false, "Invalid signature length");
        }

        (signature, hash_type)
    }

    // OP_0 ... OP_16 AND OP_1NEGATE
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

    pub fn op_equalverify(&mut self) {
        let value1 = self.pop().storage();
        let value2 = self.pop().storage();

        assert(value1 == value2);
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

    pub fn op_verify(&mut self) -> bool {
        if self.data.len() == 0 {
            false
        } else {
            if vec_to_i32(self.pop()) == 0 {
                false
            } else {
                true
            }
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
        let hash = ripemd160(self.pop_bytes::<LEN>());
        let mut vec = BoundedVec::new();
        vec.extend_from_slice(hash);
        self.push(vec);
    }

    pub fn op_sha1<let LEN: u32>(&mut self) {
        let hash = sha1::digest(self.pop_bytes::<LEN>());
        let mut vec = BoundedVec::new();
        vec.extend_from_slice(hash);
        self.push(vec);
    }

    pub fn op_sha256<let LEN: u32>(&mut self) {
        let hash = sha256::digest(self.pop_bytes::<LEN>());
        let mut vec = BoundedVec::new();
        vec.extend_from_slice(hash);
        self.push(vec);
    }

    pub fn get_last_stack_element_length(&mut self) -> u32 {
        self.data[self.stack_size - 1].len()
    }

    pub fn op_hash160<let LEN: u32>(&mut self) {
        let hash = sha256::digest(self.pop_bytes::<LEN>());
        let dhash = ripemd160(hash);
        let mut vec = BoundedVec::new();
        vec.extend_from_slice(dhash);
        self.push(vec);
    }

    pub fn op_hash256<let LEN: u32>(&mut self) {
        let hash = sha256::digest(self.pop_bytes::<LEN>());
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
    pub fn op_size(&mut self) {
        //
    }

    pub fn get_script_code_size(&mut self, address: Address) -> u32 {
        let mut size = 0;
        if address.is_p2pk() | address.is_p2pkh() {
            size = self.prev_transaction.get_script_pub_key_size(self.output_to_unlock);
        } else if address.is_p2wpkh() {
            size = 26;
        } else {
            assert(false, "not implemented");
        }
        size
    }

    fn get_sighash_all_message_hash<let SCRIPT_CODE_LEN: u32>(
        &mut self,
        address: Address,
    ) -> [u8; 32] {
        let mut message_hash = [0; 32];
        if address.is_p2pk() | address.is_p2pkh() {
            let script_code = self.prev_transaction.get_script_pub_key_with_size::<SCRIPT_CODE_LEN>(
                self.output_to_unlock,
            );
            message_hash =
                serialize_sighash_all(self.cur_transaction, self.input_to_sign, script_code);
        } else if address.is_p2wpkh() {
            let amount = self.prev_transaction.get_amount(self.output_to_unlock);
            let script_code = self.prev_transaction.get_p2wpkh_script_code(self.output_to_unlock);
            message_hash = serialize_p2wpkh_sighash_all(
                self.cur_transaction,
                self.input_to_sign,
                amount,
                script_code,
            );
        } else {
            assert(false, "not implemented");
        }
        message_hash
    }

    fn _op_checksig<let SCRIPT_CODE_LEN: u32>(&mut self, address: Address) -> bool {
        let mut message_hash = [0; 32];

        let (pub_x, pub_y) = self.pop_pubkey();
        let (mut signature, hash_type) = self.pop_signature();

        if hash_type == SIGHASH_ALL {
            message_hash = self.get_sighash_all_message_hash::<SCRIPT_CODE_LEN>(address);
        } else {
            assert(false, "Unsupported hash type");
        }

        ecdsa_verify(pub_x, pub_y, signature, message_hash)
    }

    pub fn op_checksig<let SCRIPT_CODE_LEN: u32>(&mut self, address: Address, verify: bool) {
        let result = self._op_checksig::<SCRIPT_CODE_LEN>(address);
        if verify {
            assert(result);
        } else {
            let integer = i32_to_vec(if result { 1 } else { 0 });
            self.push(integer);
        }
    }
}

type TestStack<let MAX_STACK_ELEMENT_SIZE: u32, let MAX_STACK_SIZE: u32> = Stack<MAX_STACK_ELEMENT_SIZE, MAX_STACK_SIZE, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0>;

#[test]
fn test_addition() {
    let mut stack: TestStack<100, 10> = Stack::new_test_stack();

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
    let mut stack: TestStack<100, 10> = Stack::new_test_stack();
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
    let mut stack: TestStack<100, 10> = Stack::new_test_stack();
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
    let mut stack: TestStack<100, 10> = Stack::new_test_stack();
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
    let mut stack: TestStack<100, 10> = Stack::new_test_stack();
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
    let mut stack: TestStack<100, 10> = Stack::new_test_stack();
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
    let mut stack: TestStack<100, 10> = Stack::new_test_stack();
    stack.op_num(2);
    stack.op_num(5);
    stack.op_num(3);
    stack.op_num(1);
    stack.op_pick();
    assert(vec_to_u32(stack.pop()) == 5);
}

#[test]
fn test_roll() {
    let mut stack: TestStack<100, 10> = Stack::new_test_stack();
    stack.op_num(2);
    stack.op_num(5);
    stack.op_num(3);
    stack.op_num(2);
    stack.op_roll();
    assert(vec_to_u32(stack.pop()) == 2);
}

#[test]
fn test_swaps() {
    let mut stack: TestStack<100, 10> = Stack::new_test_stack();
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
    let mut stack: TestStack<100, 10> = Stack::new_test_stack();
    stack.op_num(2);
    stack.op_num(5);
    stack.op_tuck();
    assert(vec_to_u32(stack.pop()) == 5);
    assert(vec_to_u32(stack.pop()) == 2);
    assert(vec_to_u32(stack.pop()) == 5);
}

#[test]
fn test_rots() {
    let mut stack: TestStack<100, 10> = Stack::new_test_stack();
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
    let mut stack: TestStack<20, 10> = Stack::new_test_stack();
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
    let mut stack: TestStack<20, 10> = Stack::new_test_stack();
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
    let mut stack: TestStack<32, 10> = Stack::new_test_stack();
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
    let mut stack: TestStack<20, 10> = Stack::new_test_stack();
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
    let mut stack: TestStack<32, 10> = Stack::new_test_stack();
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
    let mut stack: TestStack<100, 10> = Stack::new_test_stack();
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
    let mut stack: TestStack<100, 10> = Stack::new_test_stack();
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
    let mut stack: TestStack<100, 10> = Stack::new_test_stack();
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
fn test_legacy_checksig() {
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

    let signature_hex: str<144> = "304502203f004eeed0cef2715643e2f25a27a28f3c578e94c7f0f6a4df104e7d163f7f8f022100b8b248c1cfd8f77a0365107a9511d759b7544d979dd152a955c867afac0ef78601";
    let signature_bytes = hex_to_bytes(signature_hex);

    let pubkey_hex: str<130> = "044d05240cfbd8a2786eda9dadd520c1609b8593ff8641018d57703d02ba687cf2f187f0cee2221c3afb1b5ff7888caced2423916b61444666ca1216f26181398c";
    let pubkey_bytes = hex_to_bytes(pubkey_hex);

    stack.push_bytes(signature_bytes);
    stack.push_bytes(pubkey_bytes);

    stack.op_checksig::<26>(Address::new_p2pkh(), true);
}

#[test]
fn test_segwit_checksig() {
    // From here: https://www.blockchain.com/explorer/transactions/btc/ca7e89a098385f2053b88d4ef28974c17f2034b84116136705af366cb2a2d26f
    let cur_tx_hex = "02000000000101822952a47327be304809fb6b6c0e55a27321146e5151b1f1bccdce35bba99fb20000000000fdffffff0658020000000000002251208625054ae2eca687577e35ae70c6646fd47ff1276fe64b85a10e034f30b5136a4a010000000000001600148a8c751ab2a5fe26e68210b36019c6b0bfe024694a010000000000001600148a8c751ab2a5fe26e68210b36019c6b0bfe0246922020000000000001600148a8c751ab2a5fe26e68210b36019c6b0bfe024694a010000000000001600148a8c751ab2a5fe26e68210b36019c6b0bfe02469482b1101000000002251208625054ae2eca687577e35ae70c6646fd47ff1276fe64b85a10e034f30b5136a02483045022100acbc5aeef43fa19a7078d34e84177534c40e2ad8cee5ff4deb5aae2b4650f864022026288d3d694fdd6e592bfb5d200848206848bb0c8f0119ffee831ed7a7a148d001210310217ab07ffb6f90fb9dd925c3e950d74003ba26aad82d09b1da730ac2b3b8da00000000";
    let cur_tx_bytes = hex_to_bytes(cur_tx_hex);
    let cur_tx = Transaction::<371, 1, 1, 42, 6, 1, 211, 2, 108>::new(cur_tx_bytes, true);

    let input_to_sign = 0;

    // From here: https://www.blockchain.com/explorer/transactions/btc/b29fa9bb35cecdbcf1b151516e142173a2550e6c6bfb094830be2773a4522982
    let prev_tx_hex = "02000000000106be778a8d6493de9cae18155c3c761b9334d6223916310348c17c587f2fb7992c0500000000ffffffffb529dd3f119f36705bee141134aca6d1400fbf6ab22927ca1b16a6846ab351df0000000000ffffffffb0e5e81a0e4fa61bac8fa31f11eb0a4a58d97b6ca9b2445f36bfd26662c350000000000000ffffffffabd075d382452621f65a24d921ff4dcc813a300a9517ffb3e7a514197becb6da0000000000ffffffff4a01d9e9564bb99949ff91cc4554832f1c0c1bb37acaa02bc83f011f4a505da20000000000ffffffffcd39ad5bcb73b1c0c611dda48499c8963cb80725a2cb801d39b202558e13c3b80200000000ffffffff05e4381101000000001600148a8c751ab2a5fe26e68210b36019c6b0bfe0246900ee020000000000225120943e0e9878cf21609289994525741ddae45e83d73ffe73283c311cc65d11200fa0fd020000000000225120943e0e9878cf21609289994525741ddae45e83d73ffe73283c311cc65d11200fa062070000000000225120270da8a60c0d7f197e45cf49d3c0367c74739a9c49434ad6b491aaf88c7c57e384310900000000002251205674a20e0690c723138a032d5852fbee91f702ed83efd71f65b9b02224d34e680140c2907f4fd021b2ce513c7913d2d89692a4880a28a359f764935ff6474687547874cc2021cbc7ee97fe35040338c62311349c7fe6debdf12ea79c2122dfc7901001416027f838bc31e24523c83c9e9df04df6ba970348ae7bd5c0346062c562910a74ae4807a41dd41ac5bd83c69ce35165a6e7119d14e9c605b918ac766929599dd3830141cfee2552147af1f4112068197886359a25868cad9b17d2af7ae47784180a03f61b89bf54db4177e4db52755b2c2594314fd46850eca080c09813d12bfc699955830141ec28538e01eca31282dca1df1b018ba430a27bc8f0cd409ff4985f74bcde81e8e663bf3fe73b884bd69a54eb4c0e154552f9882b7d0f4db6db8b1d28d2edf1398301410029733548627ca3bc366575203481e94cc01ae9c03a535b40ce50d1a72472e077e6210cb227a6bc3efa4cf4bd63c94f4fdf9f523fac40eccc17e525600284b8830140ed4ba22ed2ba0eb1a21c941e261107c70942860ceccc9d69df816706e126eb7908c168c5c67f9d28993363656ecf836f889e34ada97ae6754e7dfee58d22f67000000000";
    let prev_tx_bytes = hex_to_bytes(prev_tx_hex);
    let prev_tx = Transaction::<861, 6, 1, 247, 5, 1, 204, 1, 400>::new(prev_tx_bytes, true);

    let output_to_unlock = 0;

    let mut stack = Stack::new(
        cur_tx,
        prev_tx,
        input_to_sign,
        output_to_unlock,
        empty_stack_array::<80, 7>(),
    );

    let signature_hex = "3045022100acbc5aeef43fa19a7078d34e84177534c40e2ad8cee5ff4deb5aae2b4650f864022026288d3d694fdd6e592bfb5d200848206848bb0c8f0119ffee831ed7a7a148d001";
    let signature_bytes = hex_to_bytes(signature_hex);

    let pubkey_hex = "0310217ab07ffb6f90fb9dd925c3e950d74003ba26aad82d09b1da730ac2b3b8da";
    let pubkey_bytes = hex_to_bytes(pubkey_hex);

    stack.push_bytes(signature_bytes);
    stack.push_bytes(pubkey_bytes);

    stack.op_checksig::<22>(Address::new_p2wpkh(), true);
}

use crypto::ecdsa::{
    ecdsa_verify, get_rs_from_signature, get_xy_from_compressed_pubkey,
    get_xy_from_uncompressed_pubkey,
};
use ripemd160::ripemd160;
use sha1::sha1;
use sign::address::Address;
use sign::{
    legacy::{
        serialize_sighash_all, serialize_sighash_all_anyonecanpay, serialize_sighash_none,
        serialize_sighash_none_anyonecanpay, serialize_sighash_single,
        serialize_sighash_single_anyonecanpay,
    },
    segwit::{
        serialize_p2wpkh_sighash_all, serialize_p2wpkh_sighash_all_anyonecanpay,
        serialize_p2wpkh_sighash_none, serialize_p2wpkh_sighash_none_anyonecanpay,
        serialize_p2wpkh_sighash_single, serialize_p2wpkh_sighash_single_anyonecanpay,
    },
    transaction::Transaction,
};
use sign::sig_types::{SIGHASH_ALL, SIGHASH_ANYONECANPAY, SIGHASH_NONE, SIGHASH_SINGLE};
use std::collections::bounded_vec::BoundedVec;
use utils::convert::{
    bytes_to_vec, hex_to_bytes, i32_to_le_bytes, i32_to_vec, u32_to_le_bytes, vec_to_array,
    vec_to_i32, vec_to_u32,
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
        if address.is_p2pk() | address.is_p2pkh() | address.is_p2ms() {
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
        if address.is_p2pk() | address.is_p2pkh() | address.is_p2ms() {
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

    fn get_sighash_all_anyonecanpay_message_hash<let SCRIPT_CODE_LEN: u32, let N_INPUT_SIZE: u32>(
        &mut self,
        address: Address,
    ) -> [u8; 32] {
        let mut message_hash = [0; 32];
        if address.is_p2pk() | address.is_p2pkh() {
            let script_code = self.prev_transaction.get_script_pub_key_with_size::<SCRIPT_CODE_LEN>(
                self.output_to_unlock,
            );
            message_hash = serialize_sighash_all_anyonecanpay::<CURRENT_TRANSACTION_SIZE, CURRENT_INPUT_COUNT, CURRENT_INPUT_COUNT_LEN, CURRENT_INPUT_SIZE, CURRENT_OUTPUT_COUNT, CURRENT_OUTPUT_COUNT_LEN, CURRENT_OUTPUT_SIZE, CURRENT_MAX_WITNESS_STACK_SIZE, CURRENT_WITNESS_SIZE, SCRIPT_CODE_LEN, N_INPUT_SIZE>(
                self.cur_transaction,
                self.input_to_sign,
                script_code,
            );
        } else if address.is_p2wpkh() {
            let amount = self.prev_transaction.get_amount(self.output_to_unlock);
            let script_code = self.prev_transaction.get_p2wpkh_script_code(self.output_to_unlock);
            message_hash = serialize_p2wpkh_sighash_all_anyonecanpay(
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

    fn get_sighash_none_message_hash<let SCRIPT_CODE_LEN: u32>(
        &mut self,
        address: Address,
    ) -> [u8; 32] {
        let mut message_hash = [0; 32];
        if address.is_p2pk() | address.is_p2pkh() {
            let script_code = self.prev_transaction.get_script_pub_key_with_size::<SCRIPT_CODE_LEN>(
                self.output_to_unlock,
            );
            message_hash =
                serialize_sighash_none(self.cur_transaction, self.input_to_sign, script_code);
        } else if address.is_p2wpkh() {
            let amount = self.prev_transaction.get_amount(self.output_to_unlock);
            let script_code = self.prev_transaction.get_p2wpkh_script_code(self.output_to_unlock);
            message_hash = serialize_p2wpkh_sighash_none(
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

    fn get_sighash_none_anyonecanpay_message_hash<let SCRIPT_CODE_LEN: u32, let N_INPUT_SIZE: u32>(
        &mut self,
        address: Address,
    ) -> [u8; 32] {
        let mut message_hash = [0; 32];
        if address.is_p2pk() | address.is_p2pkh() {
            let script_code = self.prev_transaction.get_script_pub_key_with_size::<SCRIPT_CODE_LEN>(
                self.output_to_unlock,
            );
            message_hash = serialize_sighash_none_anyonecanpay::<CURRENT_TRANSACTION_SIZE, CURRENT_INPUT_COUNT, CURRENT_INPUT_COUNT_LEN, CURRENT_INPUT_SIZE, CURRENT_OUTPUT_COUNT, CURRENT_OUTPUT_COUNT_LEN, CURRENT_OUTPUT_SIZE, CURRENT_MAX_WITNESS_STACK_SIZE, CURRENT_WITNESS_SIZE, SCRIPT_CODE_LEN, N_INPUT_SIZE>(
                self.cur_transaction,
                self.input_to_sign,
                script_code,
            );
        } else if address.is_p2wpkh() {
            let amount = self.prev_transaction.get_amount(self.output_to_unlock);
            let script_code = self.prev_transaction.get_p2wpkh_script_code(self.output_to_unlock);
            message_hash = serialize_p2wpkh_sighash_none_anyonecanpay(
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

    fn get_sighash_single_message_hash<let SCRIPT_CODE_LEN: u32, let N_OUTPUT_SIZE: u32, let INPUT_TO_SIGN: u32, let INPUT_TO_SIGN_LEN: u32>(
        &mut self,
        address: Address,
    ) -> [u8; 32] {
        let mut message_hash = [0; 32];
        if address.is_p2pk() | address.is_p2pkh() {
            let script_code = self.prev_transaction.get_script_pub_key_with_size::<SCRIPT_CODE_LEN>(
                self.output_to_unlock,
            );
            message_hash = serialize_sighash_single::<CURRENT_TRANSACTION_SIZE, CURRENT_INPUT_COUNT, CURRENT_INPUT_COUNT_LEN, CURRENT_INPUT_SIZE, CURRENT_OUTPUT_COUNT, CURRENT_OUTPUT_COUNT_LEN, CURRENT_OUTPUT_SIZE, CURRENT_MAX_WITNESS_STACK_SIZE, CURRENT_WITNESS_SIZE, SCRIPT_CODE_LEN, N_OUTPUT_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN>(
                self.cur_transaction,
                self.input_to_sign,
                script_code,
            );
        } else if address.is_p2wpkh() {
            let amount = self.prev_transaction.get_amount(self.output_to_unlock);
            let script_code = self.prev_transaction.get_p2wpkh_script_code(self.output_to_unlock);
            message_hash = serialize_p2wpkh_sighash_single::<CURRENT_TRANSACTION_SIZE, CURRENT_INPUT_COUNT, CURRENT_INPUT_COUNT_LEN, CURRENT_INPUT_SIZE, CURRENT_OUTPUT_COUNT, CURRENT_OUTPUT_COUNT_LEN, CURRENT_OUTPUT_SIZE, CURRENT_MAX_WITNESS_STACK_SIZE, CURRENT_WITNESS_SIZE, N_OUTPUT_SIZE>(
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

    fn get_sighash_single_anyonecanpay_message_hash<let SCRIPT_CODE_LEN: u32, let N_OUTPUT_SIZE: u32, let INPUT_TO_SIGN: u32, let INPUT_TO_SIGN_LEN: u32, let N_INPUT_SIZE: u32>(
        &mut self,
        address: Address,
    ) -> [u8; 32] {
        let mut message_hash = [0; 32];
        if address.is_p2pk() | address.is_p2pkh() {
            let script_code = self.prev_transaction.get_script_pub_key_with_size::<SCRIPT_CODE_LEN>(
                self.output_to_unlock,
            );
            message_hash = serialize_sighash_single_anyonecanpay::<CURRENT_TRANSACTION_SIZE, CURRENT_INPUT_COUNT, CURRENT_INPUT_COUNT_LEN, CURRENT_INPUT_SIZE, CURRENT_OUTPUT_COUNT, CURRENT_OUTPUT_COUNT_LEN, CURRENT_OUTPUT_SIZE, CURRENT_MAX_WITNESS_STACK_SIZE, CURRENT_WITNESS_SIZE, SCRIPT_CODE_LEN, N_OUTPUT_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN, N_INPUT_SIZE>(
                self.cur_transaction,
                self.input_to_sign,
                script_code,
            );
        } else if address.is_p2wpkh() {
            let amount = self.prev_transaction.get_amount(self.output_to_unlock);
            let script_code = self.prev_transaction.get_p2wpkh_script_code(self.output_to_unlock);
            message_hash = serialize_p2wpkh_sighash_single_anyonecanpay::<CURRENT_TRANSACTION_SIZE, CURRENT_INPUT_COUNT, CURRENT_INPUT_COUNT_LEN, CURRENT_INPUT_SIZE, CURRENT_OUTPUT_COUNT, CURRENT_OUTPUT_COUNT_LEN, CURRENT_OUTPUT_SIZE, CURRENT_MAX_WITNESS_STACK_SIZE, CURRENT_WITNESS_SIZE, N_OUTPUT_SIZE>(
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

    fn _op_checksig<let SCRIPT_CODE_LEN: u32, let N_OUTPUT_SIZE: u32, let INPUT_TO_SIGN: u32, let INPUT_TO_SIGN_LEN: u32, let N_INPUT_SIZE: u32>(
        &mut self,
        address: Address,
    ) -> bool {
        let mut message_hash = [0; 32];

        let (pub_x, pub_y) = self.pop_pubkey();
        let (mut signature, hash_type) = self.pop_signature();

        if hash_type == SIGHASH_ALL {
            message_hash = self.get_sighash_all_message_hash::<SCRIPT_CODE_LEN>(address);
        } else if hash_type == SIGHASH_NONE {
            message_hash = self.get_sighash_none_message_hash::<SCRIPT_CODE_LEN>(address);
        } else if hash_type == SIGHASH_SINGLE {
            message_hash = self
                .get_sighash_single_message_hash::<SCRIPT_CODE_LEN, N_OUTPUT_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN>(
                    address,
                );
        } else if hash_type == (SIGHASH_ALL | SIGHASH_ANYONECANPAY) {
            message_hash = self
                .get_sighash_all_anyonecanpay_message_hash::<SCRIPT_CODE_LEN, N_INPUT_SIZE>(address)
                ;
            } else if hash_type == (SIGHASH_NONE | SIGHASH_ANYONECANPAY) {
                message_hash = self
                    .get_sighash_none_anyonecanpay_message_hash::<SCRIPT_CODE_LEN, N_INPUT_SIZE>(
                        address,
                    );
            } else if hash_type == (SIGHASH_SINGLE | SIGHASH_ANYONECANPAY) {
                message_hash = self
                    .get_sighash_single_anyonecanpay_message_hash::<SCRIPT_CODE_LEN, N_OUTPUT_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN, N_INPUT_SIZE>(
                        address,
                    );
            } else {
                assert(false, "Unsupported hash type");
            }
            ecdsa_verify(pub_x, pub_y, signature, message_hash)
        }

    pub fn op_checksig<let SCRIPT_CODE_LEN: u32, let N_OUTPUT_SIZE: u32, let INPUT_TO_SIGN: u32, let INPUT_TO_SIGN_LEN: u32, let N_INPUT_SIZE: u32>(
        &mut self,
        address: Address,
        verify: bool,
    ) {
        let result = self
            ._op_checksig::<SCRIPT_CODE_LEN, N_OUTPUT_SIZE, INPUT_TO_SIGN, INPUT_TO_SIGN_LEN, N_INPUT_SIZE>(
                address,
            );
        if verify {
            assert(result);
        } else {
            let integer = i32_to_vec(if result { 1 } else { 0 });
            self.push(integer);
        }
    }

    fn _op_checkmulsig<let SCRIPT_CODE_LEN: u32, let N: u32, let M: u32>(
        &mut self,
        address: Address,
    ) -> bool {
        let n = vec_to_u32(self.pop());
        assert(n == N, "Incorrect amount of keys");

        let mut keys = [([0; 32], [0; 32]); N];
        for i in 0..N {
            keys[i] = self.pop_pubkey();
        }

        let m = vec_to_u32(self.pop());
        assert(m == M, "Incorrect amount of signatures");

        let mut sigs = [([0; 64], 0); M];
        for i in 0..M {
            sigs[i] = self.pop_signature();
        }

        let o = vec_to_u32(self.pop());
        assert(o == 0, "Incorrect structure of mulsig");

        let mut sig_now = M as i32 - 1;
        for i in 0..N {
            if sig_now >= 0 {
                let mut message_hash = [0; 32];

                let (pub_x, pub_y) = keys[N - 1 - i];
                let (signature, hash_type) = sigs[sig_now];

                if hash_type == SIGHASH_ALL {
                    message_hash = self.get_sighash_all_message_hash::<SCRIPT_CODE_LEN>(address);
                } else {
                    assert(false, "Unsupported hash type");
                }

                if ecdsa_verify(pub_x, pub_y, signature, message_hash) {
                    sig_now -= 1;
                }
            }
        }

        sig_now == -1
    }

    pub fn op_checkmulsig<let SCRIPT_CODE_LEN: u32, let N: u32, let M: u32>(
        &mut self,
        address: Address,
        verify: bool,
    ) {
        let result = self._op_checkmulsig::<SCRIPT_CODE_LEN, N, M>(address);
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
fn test_legacy_checksig_all() {
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
    //without 1 on N_INPUT_SIZE failing test
    stack.op_checksig::<26, 0, 0, 0, 1>(Address::new_p2pkh(), true);
}

#[test]
fn test_segwit_checksig_all() {
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

    stack.op_checksig::<22, 0, 0, 0, 1>(Address::new_p2wpkh(), true);
}

#[test]
fn test_legacy_checksig_all_anyonecanpay() {
    let cur_tx_hex = "01000000030dd7891efbf67da47c651531db8aab3144ed7a524e4ae1e30b773525e27ddd7b0000000000ffffffff16851666962e37a75a246101f2e340c628b1db3c045d4d3cfb2d1c0f58f97c6f0000000000ffffffffffda5d38e91fd9a0d92872d51f83cb746fc7bf5d3ff13402f8d0d5ed60ddc79c0000000000ffffffff02c0c62d00000000001976a91417194e1bd175fb5b1b2a1f9d221f6f5c29e1928388ac00c817a8040000001976a91465bda9b05f7e9a8f96a7f4ba0996a877708ef90888ac00000000";
    let cur_tx_bytes = hex_to_bytes(cur_tx_hex);
    let cur_tx = Transaction::<201, 3, 1, 124, 2, 1, 69, 0, 0>::new(cur_tx_bytes, false);

    let input_to_sign = 1;

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

    let signature_hex: str<144> = "3045022100dfd13b2aec3c6a96c550d9a51958f894ccd736dbad0013e8e722f93b5f93cce50220701f92efd753b3235d5d3c404ce263147123808bfd2b8fd4997b874105bced8381";
    let signature_bytes = hex_to_bytes(signature_hex);

    let pubkey_hex: str<130> = "0424653eac434488002cc06bbfb7f10fe18991e35f9fe4302dbea6d2353dc0ab1c119fc5009a032aa9fe47f5e149bb8442f71f884ccb516590686d8ff6ab91c613";
    let pubkey_bytes = hex_to_bytes(pubkey_hex);

    stack.push_bytes(signature_bytes);
    stack.push_bytes(pubkey_bytes);
    stack.op_checksig::<26, 0, 0, 0, 41>(Address::new_p2pkh(), true);
}

#[test]
fn test_legacy_checksig_none() {
    let cur_tx_hex = "01000000030dd7891efbf67da47c651531db8aab3144ed7a524e4ae1e30b773525e27ddd7b0000000000ffffffff16851666962e37a75a246101f2e340c628b1db3c045d4d3cfb2d1c0f58f97c6f0000000000ffffffffffda5d38e91fd9a0d92872d51f83cb746fc7bf5d3ff13402f8d0d5ed60ddc79c0000000000ffffffff02c0c62d00000000001976a91417194e1bd175fb5b1b2a1f9d221f6f5c29e1928388ac00c817a8040000001976a91465bda9b05f7e9a8f96a7f4ba0996a877708ef90888ac00000000";
    let cur_tx_bytes = hex_to_bytes(cur_tx_hex);
    let cur_tx = Transaction::<201, 3, 1, 124, 2, 1, 69, 0, 0>::new(cur_tx_bytes, false);

    let input_to_sign = 0;

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

    let signature_hex: str<144> = "304502210098a43f26f14d778c053b4dcd7df5de417b0432460bf3013d4faf0b4c46364641022000884b207007b22c7534c60c98d5f614b74ff34286c18e0b7e9e33f39cca494302";
    let signature_bytes = hex_to_bytes(signature_hex);

    let pubkey_hex: str<130> = "045be5e9478209674a96e60f1f037f6176540fd001fa1d64694770c56a7709c42c035a88c3843dbf8b10d52cc71e26cce171e1aa1e32f8e193c9f6a6bd8f07b8bf";
    let pubkey_bytes = hex_to_bytes(pubkey_hex);

    stack.push_bytes(signature_bytes);
    stack.push_bytes(pubkey_bytes);
    stack.op_checksig::<26, 0, 0, 0, 1>(Address::new_p2pkh(), true);
}

#[test]
fn test_legacy_checksig_none_anyonecanpay() {
    let cur_tx_hex = "01000000030dd7891efbf67da47c651531db8aab3144ed7a524e4ae1e30b773525e27ddd7b0000000000ffffffff16851666962e37a75a246101f2e340c628b1db3c045d4d3cfb2d1c0f58f97c6f0000000000ffffffffffda5d38e91fd9a0d92872d51f83cb746fc7bf5d3ff13402f8d0d5ed60ddc79c0000000000ffffffff02c0c62d00000000001976a91417194e1bd175fb5b1b2a1f9d221f6f5c29e1928388ac00c817a8040000001976a91465bda9b05f7e9a8f96a7f4ba0996a877708ef90888ac00000000";
    let cur_tx_bytes = hex_to_bytes(cur_tx_hex);
    let cur_tx = Transaction::<201, 3, 1, 124, 2, 1, 69, 0, 0>::new(cur_tx_bytes, false);

    let input_to_sign = 1;

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

    let signature_hex: str<144> = "3045022100de220a7cb022b3268f1d4d738527ccd128f9210aec48e8c001b96d638822730d0220092336b66c9f55925abac5d2b6a724b89c16bd167caf4f627b735d577d36e5da82";
    let signature_bytes = hex_to_bytes(signature_hex);

    let pubkey_hex: str<130> = "04bb58b5feca505c74edc000d8282fc556e51a1024fc8e7d7e56c6f887c5c8d5f202f76f508a57ac2491af19c8e67e55133f8e1cd3f9ee2350071497085f7356f8";
    let pubkey_bytes = hex_to_bytes(pubkey_hex);

    stack.push_bytes(signature_bytes);
    stack.push_bytes(pubkey_bytes);
    stack.op_checksig::<26, 0, 0, 0, 41>(Address::new_p2pkh(), true);
}


#[test]
fn test_legacy_checksig_single() {
    let cur_tx_hex = "01000000056c499afac2e1a63bb6b9461a337319b970c13c2c77be53ebc1c7c870059334000800000000ffffffff00e16741107dcd7cfa2eaeb7d767e47edbec577511b3e10f16980754c3493b090900000000ffffffff078f6ec6d77fc7e0200e12fc1e2114e56e1c5bfc869d376a87b0a1bc5f8dc50e0800000000ffffffff64289405350c34a437566b764989b50381f68cf208531c54cb205f4e859e22100800000000ffffffff291cd5940ac16559eef5a2f2b4770271959f2007b45a0d850ef5d35d134df4100900000000ffffffff010000000000000000266a24e4b883e5bda9e7a59ee4bb99e9b1bcf09f909f426974636f696e20746f20506c75746f2100000000";
    let cur_tx_bytes = hex_to_bytes(cur_tx_hex);
    let cur_tx = Transaction::<262, 5, 1, 206, 1, 1, 48, 1, 0>::new(cur_tx_bytes, false);

    let input_to_sign = 0;

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

    let signature_hex: str<144> = "3045022100bb5ccc97c010dabd6317bc85290ff3f9349d2d18bd9ad2e15d12a562c65b09d202205fcbd3ac628dc3515f6eb3ce1a8ded1de837e60a60214297cd2dc1e4f035dd2b03";
    let signature_bytes = hex_to_bytes(signature_hex);

    let pubkey_hex: str<130> = "042c0b7cf95324a07d05398b240174dc0c2be444d96b159aa6c7f7b1e668680991ae31a9c671a36543f46cea8fce6984608aa316aa0472a7eed08847440218cb2f";
    let pubkey_bytes = hex_to_bytes(pubkey_hex);

    stack.push_bytes(signature_bytes);
    stack.push_bytes(pubkey_bytes);
    stack.op_checksig::<26, 47, 0, 1, 1>(Address::new_p2pkh(), true);
}

#[test]
fn test_legacy_checksig_single_anyonecanpay() {
    let cur_tx_hex = "01000000056c499afac2e1a63bb6b9461a337319b970c13c2c77be53ebc1c7c870059334000800000000ffffffff00e16741107dcd7cfa2eaeb7d767e47edbec577511b3e10f16980754c3493b090900000000ffffffff078f6ec6d77fc7e0200e12fc1e2114e56e1c5bfc869d376a87b0a1bc5f8dc50e0800000000ffffffff64289405350c34a437566b764989b50381f68cf208531c54cb205f4e859e22100800000000ffffffff291cd5940ac16559eef5a2f2b4770271959f2007b45a0d850ef5d35d134df4100900000000ffffffff010000000000000000266a24e4b883e5bda9e7a59ee4bb99e9b1bcf09f909f426974636f696e20746f20506c75746f2100000000";
    let cur_tx_bytes = hex_to_bytes(cur_tx_hex);
    let cur_tx = Transaction::<262, 5, 1, 206, 1, 1, 48, 1, 0>::new(cur_tx_bytes, false);

    let input_to_sign = 0;

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

    let signature_hex: str<144> = "3045022100bb5ccc97c010dabd6317bc85290ff3f9349d2d18bd9ad2e15d12a562c65b09d202205fcbd3ac628dc3515f6eb3ce1a8ded1de837e60a60214297cd2dc1e4f035dd2b03";
    let signature_bytes = hex_to_bytes(signature_hex);

    let pubkey_hex: str<130> = "042c0b7cf95324a07d05398b240174dc0c2be444d96b159aa6c7f7b1e668680991ae31a9c671a36543f46cea8fce6984608aa316aa0472a7eed08847440218cb2f";
    let pubkey_bytes = hex_to_bytes(pubkey_hex);

    stack.push_bytes(signature_bytes);
    stack.push_bytes(pubkey_bytes);
    stack.op_checksig::<26, 47, 0, 1, 1>(Address::new_p2pkh(), true);
}

#[test]
fn test_p2wpkh_checksig_all() {
    let cur_tx_hex = "02000000000101ac4994014aa36b7f53375658ef595b3cb2891e1735fe5b441686f5e53338e76a0100000000ffffffff01204e0000000000001976a914ce72abfd0e6d9354a660c18f2825eb392f060fdc88ac0000000000";
    let cur_tx_bytes = hex_to_bytes(cur_tx_hex);
    let cur_tx = Transaction::<88, 1, 1, 42, 1, 1, 35, 1, 1>::new(cur_tx_bytes, true);

    let input_to_sign = 0;

    let prev_tx_hex = "0200000000010192f29384a956361b9b9ebc667d01489cb360068c22c7b89396e5fdc3ece0305a0100000000ffffffff023d0500000000000016001464193f85b629823f114c9d997ee68627d7395d5fe7a1000000000000160014d0446764c4f16f78ca0ce0b7f487cc5fe205835e024730440220598ef97f63f7648e39d03ff58383056322fa13effaee8d11c9c9e8789a72522002204dda5bbc9cba008682d62820395a2c43b9abae52d6ad81835e72bda09468fa21012103d9a4d0bbe47d58b68e366a380107ba3470f6893764a2d020127d36c169df850100000000";
    let prev_tx_bytes = hex_to_bytes(prev_tx_hex);
    let prev_tx = Transaction::<222, 1, 1, 42, 2, 1, 63, 2, 107>::new(prev_tx_bytes, true);

    let output_to_unlock = 1;

    let mut stack = Stack::new(
        cur_tx,
        prev_tx,
        input_to_sign,
        output_to_unlock,
        empty_stack_array::<80, 7>(),
    );

    let signature_hex: str<144> = "304502210090a81cb4cef2ab75e89767f8c447db07371c4e1dfd5f489736badb1a65c8d5d002205f1e58c3cf97b4351278b22171f7124652af9f55c5585875971d7fbf201ae20301";
    let signature_bytes = hex_to_bytes(signature_hex);

    let pubkey_hex: str<130> = "041428f3a3532ff4f1cac70f7292bfad06d1037f800ee8839b56ebba917a22e900ac5879295520ae5690ab668f57f8fdf6d06e410e7de064b676ce8561ec626f57";
    let pubkey_bytes = hex_to_bytes(pubkey_hex);

    stack.push_bytes(signature_bytes);
    stack.push_bytes(pubkey_bytes);
    stack.op_checksig::<26, 35, 0, 0, 1>(Address::new_p2wpkh(), true);
}

#[test]
fn test_p2wpkh_checksig_all_anyonecanpay() {
    let cur_tx_hex = "02000000000101ac4994014aa36b7f53375658ef595b3cb2891e1735fe5b441686f5e53338e76a0100000000ffffffff01204e0000000000001976a914ce72abfd0e6d9354a660c18f2825eb392f060fdc88ac0000000000";
    let cur_tx_bytes = hex_to_bytes(cur_tx_hex);
    let cur_tx = Transaction::<88, 1, 1, 42, 1, 1, 35, 1, 1>::new(cur_tx_bytes, true);

    let input_to_sign = 0;

    let prev_tx_hex = "0200000000010192f29384a956361b9b9ebc667d01489cb360068c22c7b89396e5fdc3ece0305a0100000000ffffffff023d0500000000000016001464193f85b629823f114c9d997ee68627d7395d5fe7a1000000000000160014d0446764c4f16f78ca0ce0b7f487cc5fe205835e024730440220598ef97f63f7648e39d03ff58383056322fa13effaee8d11c9c9e8789a72522002204dda5bbc9cba008682d62820395a2c43b9abae52d6ad81835e72bda09468fa21012103d9a4d0bbe47d58b68e366a380107ba3470f6893764a2d020127d36c169df850100000000";
    let prev_tx_bytes = hex_to_bytes(prev_tx_hex);
    let prev_tx = Transaction::<222, 1, 1, 42, 2, 1, 63, 2, 107>::new(prev_tx_bytes, true);

    let output_to_unlock = 1;

    let mut stack = Stack::new(
        cur_tx,
        prev_tx,
        input_to_sign,
        output_to_unlock,
        empty_stack_array::<80, 7>(),
    );

    let signature_hex: str<144> = "3045022100d477f71331af459ecc84d0d721b0fc9d1914116f64ffff651747ffe0831c019b02206b06cb80968a3565108e395fd6972c482e6a86a36b17cf0dca736fe366471cdd81";
    let signature_bytes = hex_to_bytes(signature_hex);

    let pubkey_hex: str<130> = "041428f3a3532ff4f1cac70f7292bfad06d1037f800ee8839b56ebba917a22e900ac5879295520ae5690ab668f57f8fdf6d06e410e7de064b676ce8561ec626f57";
    let pubkey_bytes = hex_to_bytes(pubkey_hex);

    stack.push_bytes(signature_bytes);
    stack.push_bytes(pubkey_bytes);
    stack.op_checksig::<26, 35, 0, 0, 1>(Address::new_p2wpkh(), true);
}

#[test]
fn test_p2wpkh_checksig_none() {
    let cur_tx_hex = "02000000000101ac4994014aa36b7f53375658ef595b3cb2891e1735fe5b441686f5e53338e76a0100000000ffffffff01204e0000000000001976a914ce72abfd0e6d9354a660c18f2825eb392f060fdc88ac0000000000";
    let cur_tx_bytes = hex_to_bytes(cur_tx_hex);
    let cur_tx = Transaction::<88, 1, 1, 42, 1, 1, 35, 1, 1>::new(cur_tx_bytes, true);

    let input_to_sign = 0;

    let prev_tx_hex = "0200000000010192f29384a956361b9b9ebc667d01489cb360068c22c7b89396e5fdc3ece0305a0100000000ffffffff023d0500000000000016001464193f85b629823f114c9d997ee68627d7395d5fe7a1000000000000160014d0446764c4f16f78ca0ce0b7f487cc5fe205835e024730440220598ef97f63f7648e39d03ff58383056322fa13effaee8d11c9c9e8789a72522002204dda5bbc9cba008682d62820395a2c43b9abae52d6ad81835e72bda09468fa21012103d9a4d0bbe47d58b68e366a380107ba3470f6893764a2d020127d36c169df850100000000";
    let prev_tx_bytes = hex_to_bytes(prev_tx_hex);
    let prev_tx = Transaction::<222, 1, 1, 42, 2, 1, 63, 2, 107>::new(prev_tx_bytes, true);

    let output_to_unlock = 1;

    let mut stack = Stack::new(
        cur_tx,
        prev_tx,
        input_to_sign,
        output_to_unlock,
        empty_stack_array::<80, 7>(),
    );

    let signature_hex: str<144> = "3045022100d0564fa7e4f4b919d6de7a46479f7b55a792f8be277c0bf46f70c303ec695747022064424a45a7a812dcc5f698a8fb0e8927dc1b5c5bd1afa728f4176913f678fbd302";
    let signature_bytes = hex_to_bytes(signature_hex);

    let pubkey_hex: str<130> = "041428f3a3532ff4f1cac70f7292bfad06d1037f800ee8839b56ebba917a22e900ac5879295520ae5690ab668f57f8fdf6d06e410e7de064b676ce8561ec626f57";
    let pubkey_bytes = hex_to_bytes(pubkey_hex);

    stack.push_bytes(signature_bytes);
    stack.push_bytes(pubkey_bytes);
    stack.op_checksig::<26, 35, 0, 0, 1>(Address::new_p2wpkh(), true);
}

#[test]
fn test_p2wpkh_checksig_none_anyonecanpay() {
    let cur_tx_hex = "02000000000101ac4994014aa36b7f53375658ef595b3cb2891e1735fe5b441686f5e53338e76a0100000000ffffffff01204e0000000000001976a914ce72abfd0e6d9354a660c18f2825eb392f060fdc88ac0000000000";
    let cur_tx_bytes = hex_to_bytes(cur_tx_hex);
    let cur_tx = Transaction::<88, 1, 1, 42, 1, 1, 35, 1, 1>::new(cur_tx_bytes, true);

    let input_to_sign = 0;

    let prev_tx_hex = "0200000000010192f29384a956361b9b9ebc667d01489cb360068c22c7b89396e5fdc3ece0305a0100000000ffffffff023d0500000000000016001464193f85b629823f114c9d997ee68627d7395d5fe7a1000000000000160014d0446764c4f16f78ca0ce0b7f487cc5fe205835e024730440220598ef97f63f7648e39d03ff58383056322fa13effaee8d11c9c9e8789a72522002204dda5bbc9cba008682d62820395a2c43b9abae52d6ad81835e72bda09468fa21012103d9a4d0bbe47d58b68e366a380107ba3470f6893764a2d020127d36c169df850100000000";
    let prev_tx_bytes = hex_to_bytes(prev_tx_hex);
    let prev_tx = Transaction::<222, 1, 1, 42, 2, 1, 63, 2, 107>::new(prev_tx_bytes, true);

    let output_to_unlock = 1;

    let mut stack = Stack::new(
        cur_tx,
        prev_tx,
        input_to_sign,
        output_to_unlock,
        empty_stack_array::<80, 7>(),
    );

    let signature_hex: str<144> = "3045022100b40060a6736bca65871655f964bafc4e2f649025ae45acd498c9b42b53a0c54702207c6d1aa55af0974c76f16ecbb862d995dc723bb10013b2a03d11acbb3ecdc46482";
    let signature_bytes = hex_to_bytes(signature_hex);

    let pubkey_hex: str<130> = "041428f3a3532ff4f1cac70f7292bfad06d1037f800ee8839b56ebba917a22e900ac5879295520ae5690ab668f57f8fdf6d06e410e7de064b676ce8561ec626f57";
    let pubkey_bytes = hex_to_bytes(pubkey_hex);

    stack.push_bytes(signature_bytes);
    stack.push_bytes(pubkey_bytes);
    stack.op_checksig::<26, 34, 0, 0, 1>(Address::new_p2wpkh(), true);
}


#[test]
fn test_p2wpkh_checksig_single() {
    let cur_tx_hex = "02000000000101ac4994014aa36b7f53375658ef595b3cb2891e1735fe5b441686f5e53338e76a0100000000ffffffff01204e0000000000001976a914ce72abfd0e6d9354a660c18f2825eb392f060fdc88ac0000000000";
    let cur_tx_bytes = hex_to_bytes(cur_tx_hex);
    let cur_tx = Transaction::<88, 1, 1, 42, 1, 1, 35, 1, 1>::new(cur_tx_bytes, true);

    let input_to_sign = 0;

    let prev_tx_hex = "0200000000010192f29384a956361b9b9ebc667d01489cb360068c22c7b89396e5fdc3ece0305a0100000000ffffffff023d0500000000000016001464193f85b629823f114c9d997ee68627d7395d5fe7a1000000000000160014d0446764c4f16f78ca0ce0b7f487cc5fe205835e024730440220598ef97f63f7648e39d03ff58383056322fa13effaee8d11c9c9e8789a72522002204dda5bbc9cba008682d62820395a2c43b9abae52d6ad81835e72bda09468fa21012103d9a4d0bbe47d58b68e366a380107ba3470f6893764a2d020127d36c169df850100000000";
    let prev_tx_bytes = hex_to_bytes(prev_tx_hex);
    let prev_tx = Transaction::<222, 1, 1, 42, 2, 1, 63, 2, 107>::new(prev_tx_bytes, true);

    let output_to_unlock = 1;

    let mut stack = Stack::new(
        cur_tx,
        prev_tx,
        input_to_sign,
        output_to_unlock,
        empty_stack_array::<80, 7>(),
    );

    let signature_hex: str<144> = "3045022100a682b1ee033be45ce935aec6f0e9bbf1f4af069b376a9dc9a8eb1643d52b3843022078e307b6fc2988fe6b3d7b84fcc93bdace768c7fb7efa8c775127efe162528a103";
    let signature_bytes = hex_to_bytes(signature_hex);

    let pubkey_hex: str<130> = "041428f3a3532ff4f1cac70f7292bfad06d1037f800ee8839b56ebba917a22e900ac5879295520ae5690ab668f57f8fdf6d06e410e7de064b676ce8561ec626f57";
    let pubkey_bytes = hex_to_bytes(pubkey_hex);

    stack.push_bytes(signature_bytes);
    stack.push_bytes(pubkey_bytes);
    stack.op_checksig::<26, 34, 0, 0, 1>(Address::new_p2wpkh(), true);
}

#[test]
fn test_p2wpkh_checksig_single_anyonecanpay() {
    let cur_tx_hex = "02000000000101ac4994014aa36b7f53375658ef595b3cb2891e1735fe5b441686f5e53338e76a0100000000ffffffff01204e0000000000001976a914ce72abfd0e6d9354a660c18f2825eb392f060fdc88ac0000000000";
    let cur_tx_bytes = hex_to_bytes(cur_tx_hex);
    let cur_tx = Transaction::<88, 1, 1, 42, 1, 1, 35, 1, 1>::new(cur_tx_bytes, true);

    let input_to_sign = 0;

    let prev_tx_hex = "0200000000010192f29384a956361b9b9ebc667d01489cb360068c22c7b89396e5fdc3ece0305a0100000000ffffffff023d0500000000000016001464193f85b629823f114c9d997ee68627d7395d5fe7a1000000000000160014d0446764c4f16f78ca0ce0b7f487cc5fe205835e024730440220598ef97f63f7648e39d03ff58383056322fa13effaee8d11c9c9e8789a72522002204dda5bbc9cba008682d62820395a2c43b9abae52d6ad81835e72bda09468fa21012103d9a4d0bbe47d58b68e366a380107ba3470f6893764a2d020127d36c169df850100000000";
    let prev_tx_bytes = hex_to_bytes(prev_tx_hex);
    let prev_tx = Transaction::<222, 1, 1, 42, 2, 1, 63, 2, 107>::new(prev_tx_bytes, true);

    let output_to_unlock = 1;

    let mut stack = Stack::new(
        cur_tx,
        prev_tx,
        input_to_sign,
        output_to_unlock,
        empty_stack_array::<80, 7>(),
    );

    let signature_hex: str<144> = "3045022100aac857ecbc5a35c079a923eddc78650bae6036a47b626e3c4089166e2747c76902203641ff9721d47134d2eafb6523df00d0dd37103143479243b6c63a920ec4146883";
    let signature_bytes = hex_to_bytes(signature_hex);

    let pubkey_hex: str<130> = "041428f3a3532ff4f1cac70f7292bfad06d1037f800ee8839b56ebba917a22e900ac5879295520ae5690ab668f57f8fdf6d06e410e7de064b676ce8561ec626f57";
    let pubkey_bytes = hex_to_bytes(pubkey_hex);

    stack.push_bytes(signature_bytes);
    stack.push_bytes(pubkey_bytes);
    stack.op_checksig::<26, 34, 0, 0, 1>(Address::new_p2wpkh(), true);
}
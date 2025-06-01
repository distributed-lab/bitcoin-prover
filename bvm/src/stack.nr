use std::hash::poseidon2::Poseidon2Hasher;
use std::hash::BuildHasherDefault;
use std::collections::map::HashMap;
use std::collections::bounded_vec::BoundedVec;

use crate::utils::{
    bytes_to_vec,
    vec_to_int,
    int_to_vec,
};

pub struct Stack {
    data: HashMap<u32, BoundedVec<u8, 520>, 1000, BuildHasherDefault<Poseidon2Hasher>>
}

impl Stack {
    pub fn new() -> Self {
        Stack {
            data: HashMap::default()
        }
    }
    
    fn push(&mut self, value: BoundedVec<u8, 520>) {
        self.data.insert(self.data.len(), value);
    }

    fn pop(&mut self) -> BoundedVec<u8, 520> {
        let value = self.data.get(self.data.len() - 1).unwrap();
        self.data.remove(self.data.len() - 1);
        value
    }

    pub fn op_1(&mut self) {
        let byte_value: [u8; 1] = [1];
        let value = bytes_to_vec(byte_value);
        self.push(value);
    }

    pub fn op_pushbytes<let N: u32>(&mut self, input: [u8; N]) {
        let value = bytes_to_vec(input);
        self.push(value);
    }

    pub fn op_equal(&mut self) {
        let value1 = self.pop();
        let value2 = self.pop();
        assert(value1 == value2);
    }

    pub fn op_add(&mut self) {
        let value1 = self.pop();
        let value2 = self.pop();

        let value3 = vec_to_int(value1) + vec_to_int(value2);
        self.push(int_to_vec(value3));
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
}
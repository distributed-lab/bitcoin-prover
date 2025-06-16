use std::hash::poseidon2::Poseidon2Hasher;
use std::hash::BuildHasherDefault;
use std::collections::map::HashMap;
use std::collections::bounded_vec::BoundedVec;

use utils::convert::{bytes_to_vec, vec_to_i32, i32_to_vec, i32_to_le_bytes};

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
}

#[test]
fn test_addition() {
    let mut stack = Stack::new();

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

    let bool_vec = stack.pop();
    let bool_value = vec_to_i32(bool_vec);
    assert(bool_value == 1);
}
use std::collections::bounded_vec::BoundedVec;

pub fn bytes_to_vec<let N: u32>(bytes: [u8; N]) -> BoundedVec<u8, 520> {
    let mut vec = BoundedVec::new();
    for i in 0..N {
        vec.push(bytes[i]);
    }
    vec
}

pub fn vec_to_int(v: BoundedVec<u8, 520>) -> i32 {
    assert(v.len() <= 4);
    let mut result: [u8; 4] = [0; 4];
    let N = v.len();
    for i in 0..4 {
        if i < N {
            result[i + 4 - N] = v.get(i);
        }
    }
    le_bytes_to_i32(result)
}

pub fn int_to_vec<let N: u32>(number: i32) -> BoundedVec<u8, 520> {
    let bytes = int_to_bytes(number);
    bytes_to_vec(bytes)
}

fn int_to_bytes(number: i32) -> [u8; 4] {
    let mut unsigned_number: u32 = 0;
    if number < 0 {
        unsigned_number = (number + 2147483647 as i32 + 1 as i32) as u32;
    } else {
        unsigned_number = number as u32;
    }
    let mut bytes = [0; 4];
    for i in 0..4 {
        bytes[i as u32] = ((unsigned_number >> (i * 8)) & 0xff) as u8;
    }
    bytes
}

fn le_bytes_to_i32(bytes: [u8; 4]) -> i32 {
    let mut result: u32 = 0;
    for i in 0..4 {
        result |= (bytes[i as u32] as u32) << (i * 8);
    }
    if result > 2147483647 {
        (result - 2147483648) as i32
    } else {
        result as i32
    }
}
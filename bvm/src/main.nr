mod utils;
mod stack;

use stack::Stack;


// This main function is generated
fn main(
    op_code_1: pub u8,
    op_code_1_input_value: pub [u8; 2],
    op_code_2: pub u8,
    op_code_2_input_value: pub [u8; 2],
    op_code_3: pub u8,
    op_code_3_input_value: pub [u8; 2],
    op_code_4: pub u8,
    op_code_5: pub u8,
) {
    let mut stack = Stack::new();

    // OP_PUSHDATA2
    assert(op_code_1 == 76);
    assert(op_code_1_input_value.len() == 2);
    stack.op_pushbytes(op_code_1_input_value);

    // OP_PUSHDATA2
    assert(op_code_2 == 76);
    assert(op_code_2_input_value.len() == 2);
    stack.op_pushbytes(op_code_2_input_value);

    // OP_PUSHDATA2
    assert(op_code_3 == 76);
    assert(op_code_3_input_value.len() == 2);
    stack.op_pushbytes(op_code_3_input_value);

    // OP_ADD
    assert(op_code_4 == 147);
    stack.op_add();

    // OP_EQUAL
    assert(op_code_5 == 135);
    stack.op_equal();

    // VERIFY
    let result = stack.verify();
    assert(result);
}
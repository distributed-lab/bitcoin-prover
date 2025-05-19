use base58::get_address;

mod base58;

fn main() {}

#[test]
fn test_base58() {
    assert(get_address::<34>([0; 20]) == "31h1vYVSYuKP6AhS86fbRdMw9XHieotbST");

    assert(
        get_address::<34>([
            184, 144, 114, 199, 223, 158, 97, 157, 0, 164, 89, 62, 138, 251, 161, 231, 184, 186, 30,
            168,
        ])
            == "3JWuJHhVg3s84J2JfMcA59doNqdCFvH6jb",
    );

    assert(
        get_address::<34>([
            216, 5, 100, 220, 11, 49, 60, 93, 156, 161, 35, 216, 193, 131, 186, 222, 82, 255, 17,
            65,
        ])
            == "3MPELm1Zt83sMD63zBDUioX4AY6W4nFB1q",
    );
}

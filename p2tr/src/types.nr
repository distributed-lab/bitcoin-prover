use dep::bignum::{BigNum, U768};
use std::ops::{Add, Div, Mul, Sub};

pub struct I768 {
    pub num: U768,
    pub is_neg: bool,
}

impl I768 {
    pub fn from(value: Field) -> Self {
        I768 { num: U768::from(value), is_neg: false }
    }

    pub fn umod(self, modulo: U768) -> Self {
        if (self.is_neg) {
            I768 { num: (modulo - U768::umod(self.num, modulo)), is_neg: false }
        } else {
            I768 { num: U768::umod(self.num, modulo), is_neg: false }
        }
    }
}

impl Add for I768 {
    fn add(self, other: Self) -> Self {
        if self.is_neg & other.is_neg {
            I768 { num: self.num + other.num, is_neg: true }
        } else if !self.is_neg & !other.is_neg {
            I768 { num: self.num + other.num, is_neg: false }
        } else {
            if self.num > other.num {
                I768 { num: self.num - other.num, is_neg: self.is_neg }
            } else {
                I768 { num: other.num - self.num, is_neg: other.is_neg }
            }
        }
    }
}

impl Sub for I768 {

    fn sub(self, other: Self) -> Self {
        if self.is_neg & other.is_neg {
            if self.num > other.num {
                I768 { num: self.num - other.num, is_neg: true }
            } else {
                I768 { num: other.num - self.num, is_neg: false }
            }
        } else if !self.is_neg & !other.is_neg {
            if self.num >= other.num {
                I768 { num: self.num - other.num, is_neg: false }
            } else {
                I768 { num: other.num - self.num, is_neg: true }
            }
        } else {
            if self.is_neg {
                I768 { num: self.num + other.num, is_neg: true }
            } else {
                I768 { num: self.num + other.num, is_neg: false }
            }
        }
    }
}

impl Mul for I768 {
    fn mul(self, other: Self) -> Self {
        let result = self.num * other.num;
        let is_neg = self.is_neg ^ other.is_neg;

        I768 { num: result, is_neg }
    }
}

impl Div for I768 {
    fn div(self, other: Self) -> Self {
        let quotient = self.num.udiv(other.num);
        let is_neg = self.is_neg ^ other.is_neg;

        I768 { num: quotient, is_neg }
    }
}

pub(crate) fn sqrt_secp256k(value: I768) -> I768 {
    let modulo: U768 = U768::from_be_bytes([
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
        0xFF, 0xFF, 0xFE, 0xFF, 0xFF, 0xFC, 0x2F,
    ]);

    // Safety:
    let res = unsafe { _sqrt_secp256k(value, modulo) };
    assert(res.mul(res).umod(modulo).num == value.num);
    res
}

// Tonelli-Shanks algorithm
unconstrained fn _sqrt_secp256k(value: I768, modulo: U768) -> I768 {
    let mut e = modulo.add(U768::one()).udiv(U768::from(4));

    let mut res1 = U768::one();
    let mut res2 = value.num;

    for _ in 0..256 {
        if !e.is_zero() {
            if e.get_limb(0) % 2 == 1 {
                res1 = (res1 * res2).umod(modulo);
            }
            res2 = (res2 * res2).umod(modulo);
            e = e.udiv(U768::from(2));
        }
    }

    I768 { num: res1, is_neg: false }
}

#[test]
fn sqrt_test() {
    // We don't need to check the result because of assert into this function
    let _ = I768::from(34);
}

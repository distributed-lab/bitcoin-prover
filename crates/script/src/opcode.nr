pub global OP_0: u8 = 0;

pub global OP_PUSHBYTES1: u8 = 1;
pub global OP_PUSHBYTES75: u8 = 75;

pub global OP_PUSHDATA1: u8 = 76;
pub global OP_PUSHDATA2: u8 = 77;
pub global OP_PUSHDATA4: u8 = 78;

pub global OP_1NEGATE: u8 = 79;
pub global OP_1: u8 = 81;
pub global OP_16: u8 = 96;

pub global OP_RETURN: u8 = 106;

pub global OP_TOALTSTACK: u8 = 107;
pub global OP_FROMALTSTACK: u8 = 108;
pub global OP_2DROP: u8 = 109;
pub global OP_2DUP: u8 = 110;
pub global OP_3DUP: u8 = 111;
pub global OP_2OVER: u8 = 112;
pub global OP_2ROT: u8 = 113;
pub global OP_2SWAP: u8 = 114;
pub global OP_IFDUP: u8 = 115;
pub global OP_DEPTH: u8 = 116;
pub global OP_DROP: u8 = 117;
pub global OP_DUP: u8 = 118;
pub global OP_NIP: u8 = 119;
pub global OP_OVER: u8 = 120;
pub global OP_PICK: u8 = 121;
pub global OP_ROLL: u8 = 122;
pub global OP_ROT: u8 = 123;
pub global OP_SWAP: u8 = 124;
pub global OP_TUCK: u8 = 125;

pub global OP_SIZE: u8 = 130;

pub global OP_1ADD: u8 = 139;
pub global OP_1SUB: u8 = 140;
pub global OP_NEGATE: u8 = 143;
pub global OP_ABS: u8 = 144;
pub global OP_NOT: u8 = 145;
pub global OP_0NOTEQUAL: u8 = 146;
pub global OP_ADD: u8 = 147;
pub global OP_SUB: u8 = 148;
pub global OP_BOOLAND: u8 = 154;
pub global OP_BOOLOR: u8 = 155;
pub global OP_NUMEQUAL: u8 = 156;
pub global OP_NUMEQUALVERIFY: u8 = 157;
pub global OP_NUMENOTQUAL: u8 = 158;
pub global OP_LESSTHAN: u8 = 159;
pub global OP_GREATERTHAN: u8 = 160;
pub global OP_LESSTHANOREQUAL: u8 = 161;
pub global OP_GREATERTHANOREQUAL: u8 = 162;
pub global OP_MIN: u8 = 163;
pub global OP_MAX: u8 = 164;
pub global OP_WITHIN: u8 = 165;

pub global OP_RIPEMD160: u8 = 166;
pub global OP_SHA1: u8 = 167;
pub global OP_SHA256: u8 = 168;
pub global OP_HASH160: u8 = 169;
pub global OP_HASH256: u8 = 170;

pub global OP_EQUAL: u8 = 135;
pub global OP_EQUALVERIFY: u8 = 136;

pub global OP_CHECKSIG: u8 = 172;
pub global OP_CHECKSIGVERIFY: u8 = 173;
pub global OP_CHECKMULSIG: u8 = 174;
pub global OP_CHECKMULSIGVERIFY: u8 = 175;
// todo: implement sigadd
pub global OP_CHECKSIGADD: u8 = 186;

pub global OP_CHECKLOCKTIMEVERIFY: u8 = 177;
pub global OP_CHECKSEQUENCEVERIFY: u8 = 178;

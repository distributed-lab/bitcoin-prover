
struct CompactSize<let N: u32> {
    /// Number of bytes in the compact size
    /// Can be 1 (FC), 2 (FD), 4 (FE), 8 (FF)
    bytes: [u8; N]
}

impl<let N: u32> CompactSize<N> {
    pub fn new(value: u64) -> Self {
        let mut result = [0; N];
        if value <= 252 {
            assert(N == 1);
            result[0] = value as u8;
        } else if value <= 65535 {
            assert(N == 3);
            result[0] = 0xfd;
            for i in 0..2 {
                result[(i + 1) as u32] = ((value >> (i * 8)) & 0xff) as u8;
            }
        } else if value <= 4294967295 {
            assert(N == 5);
            result[0] = 0xfe;
            for i in 0..4 {
                result[(i + 1) as u32] = ((value >> (i * 8)) & 0xff) as u8;
            }
        } else {
            assert(value <= 18446744073709551615);
            assert(N == 9);
            result[0] = 0xff;
            for i in 0..8 {
                result[(i + 1) as u32] = ((value >> (i * 8)) & 0xff) as u8;
            }
        }
        Self { bytes: result }
    }

    pub fn value(self) -> u64 {
        let mut result = 0;
        for i in 1..self.bytes.len() {
            result |= (self.bytes[i] as u64) << ((i - 1) as u8 * 8);
        }
        result
    }
}

pub struct Transaction {
    version: [u8; 4],
    marker: u8,
    flag: u8,
}

#[test]
fn test_compact_size() {
    // Test FC
    let compact_size = CompactSize::new(0x7b);
    assert(compact_size.bytes == [0x7b]);
    
    // Test FD
    let compact_size = CompactSize::new(0x1234);
    assert(compact_size.bytes == [0xfd, 0x34, 0x12]);

    // Test FE
    let compact_size = CompactSize::new(0x12345678);
    assert(compact_size.bytes == [0xfe, 0x78, 0x56, 0x34, 0x12]);

    // Test FF
    let compact_size = CompactSize::new(0x123456789abcdef);
    assert(compact_size.bytes == [0xff, 0xef, 0xcd, 0xab, 0x89, 0x67, 0x45, 0x23, 0x01]);
}
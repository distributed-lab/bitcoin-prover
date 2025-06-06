use super::compact_size::CompactSize;

pub struct Transaction {
    version: [u8; 4],
    marker: u8,
    flag: u8,
}

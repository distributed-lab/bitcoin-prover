use block::BlockHeader;
use chain::check_chain;

pub mod block;
pub mod convert;
pub mod target;
pub mod chain;

fn main(blocks: [BlockHeader; 150]) -> pub bool {
    check_chain(blocks)
}

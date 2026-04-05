
use tiny_keccak::{Hasher, Keccak};

fn main() {
    let address = "2e081c9b11833c78fc56aebcb89f796741b8f71e";
    let addr_bytes = hex::decode(address).unwrap();
    
    let mut hasher = Keccak::v256();
    hasher.update(&addr_bytes);
    let mut hash = [0u8; 32];
    hasher.finalize(&mut hash);
    
    println!("Hash: 0x{}", hex::encode(hash));
    
    let mut bits = Vec::new();
    for i in 0..20 {
        let byte_idx = 31 - (i / 8);
        let bit_idx = i % 8;
        let bit = (hash[byte_idx] >> bit_idx) & 1;
        bits.push(bit);
    }
    println!("Bits: {:?}", bits);
}

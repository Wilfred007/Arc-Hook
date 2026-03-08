use tiny_keccak::{Hasher, Keccak};
use crate::kzg::field::Fr;

/// Map an Ethereum address string to 20 boolean bits on the hypercube.
///
/// Matches the bit extraction in `WhitelistVerifier.sol`:
///   bytes32 hash = keccak256(abi.encodePacked(addr));
///   bit[i] = (uint256(hash) >> i) & 1
///
/// `uint256(hash)` treats the 32-byte hash as a big-endian 256-bit integer.
/// So bit 0 is the LSB of hash[31], bit 7 is the MSB of hash[31],
/// bit 8 is the LSB of hash[30], etc.
pub fn address_to_hypercube_bits(address: &str) -> Vec<bool> {
    let addr_bytes = hex::decode(address.trim_start_matches("0x")).unwrap_or_default();

    let mut hasher = Keccak::v256();
    hasher.update(&addr_bytes);
    let mut hash = [0u8; 32];
    hasher.finalize(&mut hash);

    // hash is big-endian (keccak output):
    //   hash[0]  = most significant byte of uint256(hash)
    //   hash[31] = least significant byte of uint256(hash)
    //
    // bit i = (uint256(hash) >> i) & 1
    //       = (hash[31 - i/8] >> (i%8)) & 1   (reading from LSB end)
    let mut bits = Vec::with_capacity(20);
    for i in 0..20 {
        let byte_idx = 31 - (i / 8); // LSB-first: start from hash[31]
        let bit_idx = i % 8;
        let bit = (hash[byte_idx] >> bit_idx) & 1;
        bits.push(bit == 1);
    }
    bits
}

/// Build the 2^num_vars evaluation table for the whitelist indicator polynomial.
///
/// `table[idx] = Fr::one()` if any address in `whitelisted_addresses` maps to `idx`,
/// `Fr::zero()` otherwise.
pub fn build_table(whitelisted_addresses: &[String], num_vars: usize) -> Vec<Fr> {
    let size = 1 << num_vars;
    let mut table = vec![Fr::zero(); size];

    for addr in whitelisted_addresses {
        let bits = address_to_hypercube_bits(addr);
        // Reconstruct the hypercube index from the bits.
        // bit[i] is the i-th dimension, so idx = Σ bits[i] * 2^i
        let mut idx: usize = 0;
        for (i, &bit) in bits.iter().take(num_vars).enumerate() {
            if bit {
                idx |= 1 << i;
            }
        }
        if idx < size {
            table[idx] = Fr::one();
        }
    }

    table
}

/// Encode an Ethereum address as a string from a raw 20-byte array.
pub fn address_bytes_to_hex(addr_bytes: &[u8; 20]) -> String {
    format!("0x{}", hex::encode(addr_bytes))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bits_length() {
        let bits = address_to_hypercube_bits("0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045");
        assert_eq!(bits.len(), 20);
    }

    #[test]
    fn test_same_address_same_bits() {
        let addr = "0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045";
        let bits1 = address_to_hypercube_bits(addr);
        let bits2 = address_to_hypercube_bits(addr);
        assert_eq!(bits1, bits2);
    }

    #[test]
    fn test_different_addresses_different_bits() {
        let bits1 = address_to_hypercube_bits("0x0000000000000000000000000000000000000001");
        let bits2 = address_to_hypercube_bits("0x0000000000000000000000000000000000000002");
        assert_ne!(bits1, bits2);
    }

    #[test]
    fn test_build_table_single_address() {
        let addr = "0x0000000000000000000000000000000000000001".to_string();
        let table = build_table(&[addr.clone()], 20);
        assert_eq!(table.len(), 1 << 20);
        // Exactly one entry should be 1
        let ones: usize = table.iter().filter(|&&ref x| *x == Fr::one()).count();
        assert_eq!(ones, 1);
    }

    #[test]
    fn test_build_table_empty() {
        let table = build_table(&[], 4);
        let ones: usize = table.iter().filter(|&&ref x| *x == Fr::one()).count();
        assert_eq!(ones, 0);
    }
}

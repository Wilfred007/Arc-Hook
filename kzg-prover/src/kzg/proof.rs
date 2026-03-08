use crate::kzg::field::{Fr, G1};
use crate::kzg::commit::commit;

/// Generate a multilinear KZG opening proof for the whitelist indicator polynomial.
///
/// Given:
///   - `point`: the n boolean coordinates of the address being proven (z_0, ..., z_{n-1})
///   - `table`: the 2^n evaluations of the polynomial on {0,1}^n
///   - `srs`: the structured reference string ([G1*τ^0, ..., G1*τ^(size-1)])
///
/// Returns n G1 quotient commitments, one per dimension.
///
/// The proof certifies that f(point) = the claimed value (should be 1 for whitelisted).
///
/// # Protocol (multilinear sumcheck / tensor opening)
/// Each round i folds the current table along dimension i:
///   q_i[j] = f_i(1, j) - f_i(0, j)    (the quotient polynomial for dimension i)
///   f_{i+1}[j] = f_i(z_i, j)            (fold along z_i)
/// The quotient commitment Q_i = commit(q_i, sub_srs_i).
///
/// The verifier checks: e(Q_i, [τ]₂ - [z_i]₂) = e(C_i - C_{i+1}, [1]₂)
/// using the BLS12-381 pairing (see WhitelistVerifier.sol for production TODO).
pub fn generate_proof(point: &[bool], table: &[Fr], srs: &[G1]) -> Vec<G1> {
    let num_vars = point.len();
    assert_eq!(table.len(), 1 << num_vars, "table size must be 2^num_vars");
    assert!(srs.len() >= table.len(), "SRS must be at least as large as table");

    let mut current_table = table.to_vec();
    let mut proof = Vec::with_capacity(num_vars);

    for i in 0..num_vars {
        let size = current_table.len(); // 2^(num_vars - i)
        let half = size >> 1;           // 2^(num_vars - i - 1)

        // 1. Compute the quotient polynomial for dimension i:
        //    q[j] = f(1, j_rest) - f(0, j_rest)
        //    where j is a (num_vars-i-1)-bit index, and 0/1 is the current dimension.
        let mut quotient_coeffs = Vec::with_capacity(half);
        for j in 0..half {
            // In the tensor layout: even indices = f(0,...), odd indices = f(1,...)
            // q[j] = table[2j+1] - table[2j]
            quotient_coeffs.push(current_table[2 * j + 1].sub(&current_table[2 * j]));
        }

        // 2. Commit to the quotient polynomial using the first `half` SRS points.
        //    In a proper tensor SRS for dimension i, the base points would be
        //    the sub-SRS for the remaining (n-i-1) variables. Using srs[0..half]
        //    is the correct choice for a monomial SRS ordered by index.
        let sub_srs = &srs[0..half];
        proof.push(commit(&quotient_coeffs, sub_srs));

        // 3. Fold the table along coordinate z_i:
        //    f_{next}[j] = (1 - z_i) * f(0, j) + z_i * f(1, j)
        //    Since z_i is boolean:
        //      z_i = false → f_{next}[j] = f(0, j) = table[2j]
        //      z_i = true  → f_{next}[j] = f(1, j) = table[2j+1]
        let mut next_table = Vec::with_capacity(half);
        for j in 0..half {
            if point[i] {
                next_table.push(current_table[2 * j + 1]);
            } else {
                next_table.push(current_table[2 * j]);
            }
        }
        current_table = next_table;
    }

    // After n rounds, current_table has 1 element: f(point)
    // This is the claimed evaluation value (should be Fr::one() for whitelisted).
    proof
}

/// Returns the evaluation of the polynomial at the given point after folding.
/// Useful for verification: should return Fr::one() for whitelisted addresses.
pub fn evaluate(point: &[bool], table: &[Fr]) -> Fr {
    let num_vars = point.len();
    assert_eq!(table.len(), 1 << num_vars);

    let mut current = table.to_vec();
    for i in 0..num_vars {
        let half = current.len() >> 1;
        let mut next = Vec::with_capacity(half);
        for j in 0..half {
            if point[i] {
                next.push(current[2 * j + 1]);
            } else {
                next.push(current[2 * j]);
            }
        }
        current = next;
    }
    current[0]
}

/// ABI-encode the proof as hookData for WhitelistVerifier.verify().
///
/// Solidity side decodes: (uint256 claimedValue, uint256[20] evalPoint, bytes[20] quotientCommitments)
/// We hand-encode the ABI tuple to match `abi.encode(claimedValue, evalPoint, quotients)`.
pub fn encode_hookdata(point: &[bool], quotient_commitments: &[G1]) -> Vec<u8> {
    assert_eq!(point.len(), 20);
    assert_eq!(quotient_commitments.len(), 20);

    // ABI encoding of (uint256, uint256[20], bytes[20])
    // This is a tuple with 3 components. ABI rules:
    //   - uint256 claimedValue: 32 bytes inline
    //   - uint256[20] evalPoint: 20 * 32 = 640 bytes inline (fixed-size array)
    //   - bytes[20] quotientCommitments: dynamic, encoded with head offset + tail data
    //
    // For (uint256, uint256[20], bytes[20]):
    // Head (offsets): claimedValue(32) | evalPoint(640) | offset_to_bytes_array(32)
    // Then the bytes[20] dynamic encoding.

    let mut out = Vec::new();

    // claimedValue = 1 (padded to 32 bytes, big-endian)
    let mut claimed = [0u8; 32];
    claimed[31] = 1;
    out.extend_from_slice(&claimed);

    // evalPoint[20]: each bit as a uint256 (32 bytes)
    for &bit in point.iter() {
        let mut word = [0u8; 32];
        if bit { word[31] = 1; }
        out.extend_from_slice(&word);
    }

    // bytes[20] is a dynamic type. Its head slot is the offset to the bytes[20] data.
    // Current offset from start of the tuple encoding:
    //   32 (claimedValue) + 640 (evalPoint) + 32 (offset slot) = 704 bytes before the data
    let offset_to_bytes_array: u32 = 32 + 640; // offset from the start of the offset slot onwards
    let mut offset_word = [0u8; 32];
    offset_word[28..32].copy_from_slice(&offset_to_bytes_array.to_be_bytes());
    out.extend_from_slice(&offset_word);

    // bytes[20] dynamic encoding:
    // First: 20 offsets (one per element), each pointing to the element's length+data
    // Then: each element encoded as length (32 bytes) + data (padded to 32-byte boundary)
    //
    // Each compressed G1 point is 48 bytes. Padded to 64 bytes (next multiple of 32).

    let element_size = 48usize;
    let element_padded = ((element_size + 31) / 32) * 32; // 64 bytes
    let per_element_encoded = 32 + element_padded;        // 32 (len) + 64 (data) = 96 bytes

    // Offsets within the bytes[20] tail section (relative to start of the 20-offset block)
    for i in 0..20usize {
        let elem_offset = 20 * 32 + i * per_element_encoded; // past the 20 offset words
        let mut off = [0u8; 32];
        off[28..32].copy_from_slice(&(elem_offset as u32).to_be_bytes());
        out.extend_from_slice(&off);
    }

    // Write each element: length word + padded data
    for qc in quotient_commitments.iter() {
        let compressed = qc.compress(); // 48 bytes

        // Length word (32 bytes)
        let mut len_word = [0u8; 32];
        len_word[29..32].copy_from_slice(&(element_size as u32).to_be_bytes()[1..]); // 48 as 3 bytes
        len_word[30] = 0;
        len_word[31] = 48;
        out.extend_from_slice(&len_word);

        // Data padded to 64 bytes
        let mut data = [0u8; 64];
        data[..48].copy_from_slice(&compressed);
        out.extend_from_slice(&data);
    }

    out
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::kzg::{encoding, srs};

    fn setup(num_vars: usize) -> (Vec<crate::kzg::field::G1>, Vec<Fr>) {
        let srs_data = srs::load_srs(num_vars);
        let addresses = vec![
            "0x0000000000000000000000000000000000000001".to_string(),
        ];
        let table = encoding::build_table(&addresses, num_vars);
        (srs_data, table)
    }

    #[test]
    fn test_evaluate_whitelisted() {
        let num_vars = 4;
        let (_, table) = setup(num_vars);
        let addr = "0x0000000000000000000000000000000000000001";
        let point = encoding::address_to_hypercube_bits(addr);
        let point_n: Vec<bool> = point[..num_vars].to_vec();
        let eval = evaluate(&point_n, &table);
        assert_eq!(eval, Fr::one(), "whitelisted address should evaluate to 1");
    }

    #[test]
    fn test_evaluate_not_whitelisted() {
        let num_vars = 4;
        let (_, table) = setup(num_vars);
        let addr = "0x0000000000000000000000000000000000000002"; // not whitelisted
        let point = encoding::address_to_hypercube_bits(addr);
        let point_n: Vec<bool> = point[..num_vars].to_vec();
        let eval = evaluate(&point_n, &table);
        assert_eq!(eval, Fr::zero(), "non-whitelisted address should evaluate to 0");
    }

    #[test]
    fn test_proof_length() {
        let num_vars = 4;
        let (srs_data, table) = setup(num_vars);
        let addr = "0x0000000000000000000000000000000000000001";
        let point = encoding::address_to_hypercube_bits(addr);
        let point_n: Vec<bool> = point[..num_vars].to_vec();
        let proof = generate_proof(&point_n, &table, &srs_data);
        assert_eq!(proof.len(), num_vars);
    }
}

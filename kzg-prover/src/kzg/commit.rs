use rayon::prelude::*;
use blst::blst_uint64_from_fr;
use crate::kzg::field::{Fr, G1};

/// Commit to a multilinear polynomial given by its evaluations on the boolean hypercube.
///
/// `table[i]` is the polynomial value at the i-th vertex of {0,1}^n.
/// For a whitelist indicator table, these values are 0 or 1.
///
/// Returns a single G1 commitment point: Σ table[i] * srs[i].
/// Because table values are 0/1, this reduces to summing the SRS points
/// at positions where table[i] == 1.
pub fn commit(table: &[Fr], srs: &[G1]) -> G1 {
    assert_eq!(table.len(), srs.len(), "table and SRS must have the same length");

    // Parallel MSM: sum srs[i] for every i where table[i] == Fr::one()
    let sum = table
        .par_iter()
        .enumerate()
        .filter(|(_, val)| {
            // Extract canonical u64 limbs and check equality to 1
            let mut limbs = [0u64; 4];
            unsafe { blst_uint64_from_fr(limbs.as_mut_ptr(), &val.0) };
            limbs[0] == 1 && limbs[1] == 0 && limbs[2] == 0 && limbs[3] == 0
        })
        .map(|(i, _)| srs[i])
        .reduce(G1::identity, |acc, point| acc.add(&point));

    sum
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::kzg::srs::load_srs;

    #[test]
    fn test_commit_empty_table() {
        // All-zero table should commit to the identity point
        let n = 3;
        let srs = load_srs(n);
        let table = vec![Fr::zero(); 1 << n];
        let c = commit(&table, &srs);
        assert_eq!(c.compress(), G1::identity().compress());
    }

    #[test]
    fn test_commit_single_entry() {
        // Table with only index 2 set to 1 should give commitment = srs[2]
        let n = 3;
        let srs = load_srs(n);
        let mut table = vec![Fr::zero(); 1 << n];
        table[2] = Fr::one();
        let c = commit(&table, &srs);
        // srs[2] = G1 * τ^2
        assert_eq!(c.compress(), srs[2].compress());
    }

    #[test]
    fn test_commit_two_entries() {
        // Table with indices 1 and 3 set should give srs[1] + srs[3]
        let n = 3;
        let srs = load_srs(n);
        let mut table = vec![Fr::zero(); 1 << n];
        table[1] = Fr::one();
        table[3] = Fr::one();
        let c = commit(&table, &srs);
        let expected = srs[1].add(&srs[3]);
        assert_eq!(c.compress(), expected.compress());
    }
}

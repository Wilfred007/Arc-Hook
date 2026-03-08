use crate::kzg::field::{Fr, G1};

/// Load a Structured Reference String (SRS) of size 2^num_vars.
///
/// Returns a vector [G1*τ^0, G1*τ^1, ..., G1*τ^(size-1)] where
/// τ is the "toxic waste" scalar from the trusted setup.
///
/// # Development mode
/// Uses a fixed τ = 7 (a well-known dev constant). This is cryptographically
/// weak — the discrete log of τ is known. Do NOT use in production.
///
/// # Production
/// Replace this function body to load the powers-of-tau from a real trusted
/// setup file (e.g., the Ethereum KZG ceremony `.ptau` file).
/// Example: `load_srs_from_ptau("pot20_final.ptau", num_vars)`
pub fn load_srs(num_vars: usize) -> Vec<G1> {
    let size = 1 << num_vars;
    let g1 = G1::generator();

    // τ = 7  (development constant — MUST be replaced in production)
    let tau = Fr::from_u64(7);

    let mut srs = Vec::with_capacity(size);
    let mut tau_power = Fr::one(); // τ^0 = 1

    for _ in 0..size {
        // srs[i] = G1 * τ^i
        srs.push(g1.mul(&tau_power));
        // advance: τ^(i+1) = τ^i * τ
        tau_power = tau_power.mul(&tau);
    }

    srs
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_srs_length() {
        let srs = load_srs(3);
        assert_eq!(srs.len(), 8);
    }

    #[test]
    fn test_srs_first_element_is_generator() {
        // srs[0] = G1 * τ^0 = G1 * 1 = G1 (generator)
        let srs = load_srs(2);
        let g1 = G1::generator();
        assert_eq!(
            srs[0].compress(),
            g1.mul(&crate::kzg::field::Fr::one()).compress()
        );
    }

    #[test]
    fn test_srs_elements_differ() {
        let srs = load_srs(4);
        // G1*τ^0 ≠ G1*τ^1 ≠ G1*τ^2 for τ ≠ 0,1
        assert_ne!(srs[0].compress(), srs[1].compress());
        assert_ne!(srs[1].compress(), srs[2].compress());
    }
}

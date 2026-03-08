use blst::*;

use std::fmt;

#[derive(Clone, Copy)]
pub struct Fr(pub blst_fr);
#[derive(Clone, Copy)]
pub struct G1(pub blst_p1);
#[derive(Clone, Copy)]
pub struct G2(pub blst_p2);

impl fmt::Debug for Fr {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "Fr(0x{})", hex::encode(self.to_bytes_be()))
    }
}

impl fmt::Debug for G1 {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "G1(0x{})", hex::encode(self.compress()))
    }
}

impl fmt::Debug for G2 {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let mut out = [0u8; 96];
        unsafe { blst_p2_compress(out.as_mut_ptr(), &self.0) };
        write!(f, "G2(0x{})", hex::encode(out))
    }
}

impl PartialEq for Fr {
    fn eq(&self, other: &Self) -> bool {
        self.limbs() == other.limbs()
    }
}

impl Eq for Fr {}

impl PartialEq for G1 {
    fn eq(&self, other: &Self) -> bool {
        self.compress() == other.compress()
    }
}

impl Eq for G1 {}

impl PartialEq for G2 {
    fn eq(&self, other: &Self) -> bool {
        let mut out_self = [0u8; 96];
        let mut out_other = [0u8; 96];
        unsafe {
            blst_p2_compress(out_self.as_mut_ptr(), &self.0);
            blst_p2_compress(out_other.as_mut_ptr(), &other.0);
        }
        out_self == out_other
    }
}

impl Eq for G2 {}

impl Fr {
    pub fn zero() -> Self {
        let mut fr = blst_fr::default();
        unsafe { blst_fr_from_uint64(&mut fr, [0, 0, 0, 0].as_ptr()) };
        Fr(fr)
    }

    pub fn one() -> Self {
        let mut fr = blst_fr::default();
        unsafe { blst_fr_from_uint64(&mut fr, [1, 0, 0, 0].as_ptr()) };
        Fr(fr)
    }

    pub fn from_u64(val: u64) -> Self {
        let mut fr = blst_fr::default();
        unsafe { blst_fr_from_uint64(&mut fr, [val, 0, 0, 0].as_ptr()) };
        Fr(fr)
    }

    /// Returns the 4 u64 limbs of this element in canonical (non-Montgomery) form.
    pub fn limbs(&self) -> [u64; 4] {
        let mut out = [0u64; 4];
        unsafe { blst_uint64_from_fr(out.as_mut_ptr(), &self.0) };
        out
    }

    /// Serialize to 32-byte big-endian.
    pub fn to_bytes_be(&self) -> [u8; 32] {
        let limbs = self.limbs();
        let mut out = [0u8; 32];
        for (i, &limb) in limbs.iter().enumerate() {
            let start = (3 - i) * 8;
            out[start..start + 8].copy_from_slice(&limb.to_be_bytes());
        }
        out
    }

    /// Serialize to 32-byte little-endian (u64 limbs in LE order).
    pub fn to_bytes_le(&self) -> [u8; 32] {
        let limbs = self.limbs();
        let mut out = [0u8; 32];
        for (i, &limb) in limbs.iter().enumerate() {
            out[i * 8..(i + 1) * 8].copy_from_slice(&limb.to_le_bytes());
        }
        out
    }

    /// Field addition.
    pub fn add(&self, other: &Self) -> Self {
        let mut res = blst_fr::default();
        unsafe { blst_fr_add(&mut res, &self.0, &other.0) };
        Fr(res)
    }

    /// Field subtraction (self - other).
    pub fn sub(&self, other: &Self) -> Self {
        let mut res = self.0;
        let mut neg_other = other.0;
        unsafe {
            blst_fr_cneg(&mut neg_other, &other.0, true);
            blst_fr_add(&mut res, &self.0, &neg_other);
        }
        Fr(res)
    }

    /// Field multiplication.
    pub fn mul(&self, other: &Self) -> Self {
        let mut res = blst_fr::default();
        unsafe { blst_fr_mul(&mut res, &self.0, &other.0) };
        Fr(res)
    }
}



impl G1 {
    pub fn generator() -> Self {
        unsafe { G1(*blst_p1_generator()) }
    }

    pub fn identity() -> Self {
        G1(blst_p1::default())
    }

    /// Scalar multiplication: self * scalar.
    /// Uses blst_p1_mult with the scalar in little-endian byte form.
    pub fn mul(&self, scalar: &Fr) -> G1 {
        let mut out = blst_p1::default();
        // Convert Fr to 32 little-endian bytes via canonical u64 limbs.
        let scalar_bytes = scalar.to_bytes_le();
        unsafe { blst_p1_mult(&mut out, &self.0, scalar_bytes.as_ptr(), 255) };
        G1(out)
    }

    /// Add two G1 points.
    pub fn add(&self, other: &G1) -> G1 {
        let mut out = blst_p1::default();
        unsafe { blst_p1_add_or_double(&mut out, &self.0, &other.0) };
        G1(out)
    }

    /// Compress to 48 bytes (BLS12-381 compressed G1).
    pub fn compress(&self) -> [u8; 48] {
        let mut out = [0u8; 48];
        unsafe { blst_p1_compress(out.as_mut_ptr(), &self.0) };
        out
    }
}

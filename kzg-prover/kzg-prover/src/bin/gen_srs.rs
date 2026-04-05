use blst::*;

fn main() {
    let tau_base = 7u64;
    let mut tau = blst_fr::default();
    unsafe { blst_fr_from_uint64(&mut tau, [tau_base, 0, 0, 0].as_ptr()) };

    println!("[");
    for i in 0..20 {
        let mut t_i = blst_fr::default();
        let exp = 1u64 << i;
        
        // Compute tau^{2^i}
        let mut current_tau = tau;
        // This is inefficient but works for tau=7 and small i
        // Actually, let's just use pow or repeated mul
        let mut power = blst_fr::default();
        unsafe {
            let mut val = [0u64; 4];
            val[0] = exp;
            // blst_fr_pow doesn't exist? Use repeated squaring or something.
            // Wait, for 2^i, it's just i repeated squarings of tau.
            let mut res = tau;
            for _ in 0..i {
                let mut tmp = blst_fr::default();
                blst_fr_sqr(&mut tmp, &res);
                res = tmp;
            }
            
            let mut g2 = blst_p2::default();
            blst_p2_mult(&mut g2, blst_p2_generator(), res.l, 255);
            
            let mut out = [0u8; 192];
            blst_p2_serialize(out.as_mut_ptr(), &g2);
            println!("    hex\"{}\",", hex::encode(out));
        }
    }
    println!("]");
}

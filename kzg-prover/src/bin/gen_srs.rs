use blst::*;
use hex;

fn main() {
    let tau_base = 7u64;
    let mut tau = blst_fr::default();
    unsafe { blst_fr_from_uint64(&mut tau, [tau_base, 0, 0, 0].as_ptr()) };

    println!("[");
    for i in 0..20 {
        let exp = 1u64 << i;
        
        unsafe {
            // Compute tau^{2^i} via repeated squaring
            let mut res = tau;
            for _ in 0..i {
                let mut tmp = blst_fr::default();
                blst_fr_sqr(&mut tmp, &res);
                res = tmp;
            }
            
            let mut g2 = blst_p2::default();
            // p2_mult takes scalar as little-endian bytes
            let mut res_bytes = [0u8; 32];
            blst_uint64_from_fr(res_bytes.as_mut_ptr() as *mut u64, &res);
            
            blst_p2_mult(&mut g2, blst_p2_generator(), res_bytes.as_ptr(), 255);
            
            let mut out = [0u8; 192];
            blst_p2_serialize(out.as_mut_ptr(), &g2);
            println!("    hex\"{}\",", hex::encode(out));
        }
    }
    println!("]");
}

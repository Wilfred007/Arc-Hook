use actix_web::{get, web, App, HttpServer, HttpResponse, Responder};
use actix_cors::Cors;
use serde::Serialize;
use crate::db::Database;
use crate::kzg::{field::G1, encoding, proof};
use std::sync::{Arc, Mutex};

pub struct AppState {
    pub db: Arc<Mutex<Database>>,
    pub srs: Arc<Vec<G1>>,
    pub num_vars: usize,
}

#[derive(Serialize)]
struct StatusResponse {
    latest_block: u64,
    latest_commitment: String,
    whitelisted_count: usize,
}

#[derive(Serialize)]
struct ProofResponse {
    address: String,
    hook_data: String, // hex encoded ABI data
}

#[derive(Serialize)]
struct ErrorResponse {
    error: String,
}

#[get("/status")]
async fn get_status(data: web::Data<AppState>) -> impl Responder {
    let db = data.db.lock().unwrap();
    
    let latest_block = db.get_sync_state("last_processed_block")
        .unwrap_or(None)
        .and_then(|s| s.parse::<u64>().ok())
        .unwrap_or(0);
        
    let latest_commitment = db.get_sync_state("last_commitment")
        .unwrap_or(None)
        .unwrap_or_else(|| "0x00".to_string());
        
    let addresses = db.get_all_addresses().unwrap_or_default();
    
    HttpResponse::Ok().json(StatusResponse {
        latest_block,
        latest_commitment,
        whitelisted_count: addresses.len(),
    })
}

#[get("/proof/{address}")]
async fn get_proof(path: web::Path<String>, data: web::Data<AppState>) -> impl Responder {
    let address = path.into_inner().to_lowercase();
    
    // 1. Check if address is whitelisted and get all addresses
    let (all_addresses, is_whitelisted) = {
        let db = data.db.lock().unwrap();
        let all = db.get_all_addresses().unwrap_or_default();
        let whitelisted = all.iter().any(|a| a.to_lowercase() == address);
        (all, whitelisted)
    };
    
    if !is_whitelisted {
        return HttpResponse::NotFound().json(ErrorResponse {
            error: format!("Address {} is not whitelisted", address),
        });
    }
    
    // 2. Build table
    let table = encoding::build_table(&all_addresses, data.num_vars);
    
    // 3. Generate bits for the target address
    let bits = encoding::address_to_hypercube_bits(&address);
    let bits_n = bits[..data.num_vars].to_vec();
    
    // 4. Generate proof
    let proof = proof::generate_proof(&bits_n, &table, &data.srs);
    
    // 5. ABI encode
    let hook_data = proof::encode_hookdata(&bits_n, &proof);
    
    HttpResponse::Ok().json(ProofResponse {
        address,
        hook_data: format!("0x{}", hex::encode(hook_data)),
    })
}

pub async fn start_server(
    db: Arc<Mutex<Database>>,
    srs: Arc<Vec<G1>>,
    num_vars: usize,
    port: u16,
) -> std::io::Result<()> {
    let app_state = web::Data::new(AppState {
        db,
        srs,
        num_vars,
    });
    
    log::info!("Starting REST API server on 0.0.0.0:{}...", port);
    
    HttpServer::new(move || {
        let cors = Cors::default()
            .allow_any_origin()
            .allow_any_method()
            .allow_any_header();
            
        App::new()
            .wrap(cors)
            .app_data(app_state.clone())
            .service(get_status)
            .service(get_proof)
    })
    .bind(("0.0.0.0", port))?
    .run()
    .await
}

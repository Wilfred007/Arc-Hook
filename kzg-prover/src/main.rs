mod kzg;
mod db;
mod chain;
mod listener;
mod server;

use anyhow::Result;
use dotenv::dotenv;
use std::env;
use std::sync::{Arc, Mutex};

#[tokio::main]
async fn main() -> Result<()> {
    dotenv().ok();
    env_logger::init();

    // ── Required ──────────────────────────────────────────────────────────
    let rpc_url          = env::var("RPC_URL").expect("RPC_URL must be set");
    let registry_address = env::var("REGISTRY_ADDRESS").expect("REGISTRY_ADDRESS must be set");
    let trigger_address  = env::var("TRIGGER_ADDRESS").expect("TRIGGER_ADDRESS must be set");

    // ── Optional (local state) ────────────────────────────────────────────
    let db_path = env::var("DB_PATH").unwrap_or_else(|_| "prover.db".to_string());
    let server_port = env::var("SERVER_PORT")
        .unwrap_or_else(|_| "8080".to_string())
        .parse::<u16>()
        .expect("SERVER_PORT must be a valid port number");

    log::info!("╔══════════════════════════════════╗");
    log::info!("║       KZG Whitelist Prover        ║");
    log::info!("╚══════════════════════════════════╝");
    log::info!("RPC:              {}", rpc_url);
    log::info!("Registry:         {}", registry_address);
    log::info!("Trigger:          {}", trigger_address);
    log::info!("DB:               {}", db_path);
    log::info!("API Port:         {}", server_port);
    log::info!(
        "Chain submission: {}",
        if env::var("PROVER_PRIVATE_KEY").is_ok() && env::var("VERIFIER_ADDRESS").is_ok() {
            "enabled"
        } else {
            "disabled (observe-only)"
        }
    );

    let database = Arc::new(Mutex::new(db::Database::open(&db_path)?));
    let client   = chain::ChainClient::new(&rpc_url);

    // Load SRS once at startup (2^20 points).
    log::info!("Loading SRS (2^20 points)…");
    let srs_data = Arc::new(kzg::srs::load_srs(20));
    log::info!("SRS loaded.");

    // ── 1. Start Log Listener (Background Task) ───────────────────────────
    let listener_db = database.clone();
    let listener_srs = srs_data.clone();
    let listener_client = client.clone();
    let listener_reg = registry_address.clone();
    let listener_trig = trigger_address.clone();

    tokio::spawn(async move {
        if let Err(e) = listener::start_listener(
            listener_client,
            listener_db,
            listener_srs,
            &listener_reg,
            &listener_trig,
        ).await {
            log::error!("Listener error: {e}");
        }
    });

    // ── 2. Start REST API (Blocking) ──────────────────────────────────────
    server::start_server(database, srs_data, 20, server_port).await?;

    Ok(())
}

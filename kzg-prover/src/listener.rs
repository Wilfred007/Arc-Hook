use crate::db::Database;
use crate::chain::ChainClient;
use crate::kzg::{encoding, commit, field::G1};
use std::time::Duration;
use std::env;
use tokio::time::sleep;

/// Number of hypercube dimensions (must match WhitelistVerifier.sol's hardcoded 20).
const NUM_VARS: usize = 20;

/// How many seconds to wait between polling rounds.
const POLL_INTERVAL_SECS: u64 = 7;

use std::sync::{Arc, Mutex};

pub async fn start_listener(
    client: ChainClient,
    db: Arc<Mutex<Database>>,
    srs_data: Arc<Vec<G1>>,
    registry_addr: &str,
    _trigger_addr: &str,
) -> anyhow::Result<()> {
    // Optional on-chain submission config (may be absent in dev)

    // Optional on-chain submission config (may be absent in dev)
    let prover_key = env::var("PROVER_PRIVATE_KEY").ok();
    let verifier_addr = env::var("VERIFIER_ADDRESS").ok();

    if prover_key.is_none() || verifier_addr.is_none() {
        log::warn!(
            "PROVER_PRIVATE_KEY / VERIFIER_ADDRESS not set — \
             commitment will be computed but NOT submitted to chain."
        );
    }

    let mut last_processed_block: u64 = db.lock().unwrap()
        .get_sync_state("last_block")?
        .and_then(|s| s.parse().ok())
        .unwrap_or(0);

    log::info!("Starting listener from block {}", last_processed_block);

    loop {
        // ── 1. Fetch new WhitelistUpdated events ──────────────────────────
        let logs = match client.get_logs(registry_addr, last_processed_block).await {
            Ok(l) => l,
            Err(e) => {
                log::error!("get_logs failed: {e}");
                sleep(Duration::from_secs(POLL_INTERVAL_SECS)).await;
                continue;
            }
        };

        if !logs.is_empty() {
            log::info!("Found {} new whitelist event(s)", logs.len());

            // ── 2. Update local DB ────────────────────────────────────────
            let mut max_nonce: u64 = 0;
            let mut max_block: u64 = last_processed_block;

            for log in &logs {
                let db_guard = db.lock().unwrap();
                if log.added {
                    db_guard.add_address(&log.address, log.nonce)?;
                    log::info!("  + added   {}", log.address);
                } else {
                    db_guard.remove_address(&log.address)?;
                    log::info!("  - removed {}", log.address);
                }
                if log.nonce > max_nonce { max_nonce = log.nonce; }
                if log.block_number > max_block { max_block = log.block_number; }
            }

            // ── 3. Recompute KZG commitment ───────────────────────────────
            let (addresses, commitment_hex) = {
                let db_guard = db.lock().unwrap();
                log::info!("Recomputing commitment over {} address(es)…",
                    db_guard.get_all_addresses()?.len());

                let addresses = db_guard.get_all_addresses()?;
                let table = encoding::build_table(&addresses, NUM_VARS);
                let commitment = commit::commit(&table, &srs_data);
                let commitment_bytes = commitment.compress().to_vec();
                let commitment_hex = hex::encode(&commitment_bytes);
                (addresses, commitment_hex)
            };

            log::info!("New commitment: 0x{}", commitment_hex);

            // ── 4. Persist state ──────────────────────────────────────────
            // Advance start block past the last processed block to avoid replaying.
            last_processed_block = max_block + 1;
            {
                let db_guard = db.lock().unwrap();
                db_guard.set_sync_state("last_block", &last_processed_block.to_string())?;
                db_guard.set_sync_state("last_commitment", &commitment_hex)?;
                db_guard.set_sync_state("last_nonce", &max_nonce.to_string())?;
            }

            // ── 5. Submit commitment to chain (if keys are configured) ────
            if let (Some(ref pk), Some(ref va)) = (&prover_key, &verifier_addr) {
                // Re-compress if we need it here, or just use the one from before
                let table = encoding::build_table(&addresses, NUM_VARS);
                let commitment = commit::commit(&table, &srs_data);
                let commitment_bytes = commitment.compress().to_vec();

                match client
                    .submit_commitment(va, commitment_bytes, max_nonce, pk)
                    .await
                {
                    Ok(tx_hash) => log::info!("Commitment submitted: {:#x}", tx_hash),
                    Err(e) => log::error!("Failed to submit commitment: {e}"),
                }
            }
        }

        sleep(Duration::from_secs(POLL_INTERVAL_SECS)).await;
    }
}

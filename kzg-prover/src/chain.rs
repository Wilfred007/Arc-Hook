use anyhow::{Context, Result};
use alloy::{
    network::EthereumWallet,
    primitives::{Address, Bytes, B256},
    providers::{Provider, ProviderBuilder},
    rpc::types::{Filter, TransactionRequest, Log},
    signers::local::PrivateKeySigner,
    sol,
    sol_types::{SolCall, SolEvent},
};

// ---------------------------------------------------------------------------
// ABI definitions via alloy's sol! macro
// ---------------------------------------------------------------------------

sol! {
    /// WhitelistRegistry event
    event WhitelistUpdated(address indexed addr, bool added, uint256 nonce);

    /// WhitelistVerifier function
    function updateCommitment(bytes _commitment, uint64 _nonce) external;
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/// Parsed representation of a WhitelistUpdated log.
#[derive(Debug, Clone)]
pub struct WhitelistLog {
    pub address: String,
    pub added: bool,
    pub nonce: u64,
    pub block_number: u64,
}

/// Ethereum client wrapping an alloy provider.
#[derive(Clone)]
pub struct ChainClient {
    rpc_url: String,
}

// ---------------------------------------------------------------------------
// Event signature topic0 for WhitelistUpdated
// ---------------------------------------------------------------------------

impl ChainClient {
    pub fn new(rpc_url: &str) -> Self {
        ChainClient {
            rpc_url: rpc_url.to_string(),
        }
    }

    /// Fetch all `WhitelistUpdated` events from `registry_addr` starting from `from_block`.
    ///
    /// Note: some RPC providers cap the log range to 10 000 blocks per request.
    /// For production, paginate by fetching in 10 000-block windows.
    pub async fn get_logs(
        &self,
        registry_addr: &str,
        from_block: u64,
    ) -> Result<Vec<WhitelistLog>> {
        let provider = ProviderBuilder::new()
            .on_http(self.rpc_url.parse().context("invalid RPC URL")?);

        let addr: Address = registry_addr
            .parse()
            .context("invalid registry address")?;

        let filter = Filter::new()
            .address(addr)
            .from_block(from_block)
            .event_signature(WhitelistUpdated::SIGNATURE_HASH);

        let raw_logs: Vec<Log> = provider
            .get_logs(&filter)
            .await
            .context("eth_getLogs failed")?;

        let mut result = Vec::with_capacity(raw_logs.len());
        for log in raw_logs {
            let block_number = log.block_number.unwrap_or(from_block);

            // Decode the log using the sol!-generated decoder
            let decoded = WhitelistUpdated::decode_log(&log.inner, true)
                .context("failed to decode WhitelistUpdated log")?;

            // Format address as lowercase hex with 0x prefix
            let address_str = format!("{:#x}", decoded.addr);

            result.push(WhitelistLog {
                address: address_str,
                added: decoded.added,
                nonce: decoded.nonce.to::<u64>(),
                block_number,
            });
        }

        Ok(result)
    }

    /// Submit an updated KZG commitment to the `WhitelistVerifier` contract.
    ///
    /// Signs a transaction from `private_key` calling `updateCommitment(bytes, uint64)`.
    /// Waits for the transaction to be included in a block.
    pub async fn submit_commitment(
        &self,
        verifier_addr: &str,
        commitment_bytes: Vec<u8>,
        nonce: u64,
        private_key: &str,
    ) -> Result<B256> {
        let signer: PrivateKeySigner = private_key
            .parse()
            .context("invalid private key")?;

        let wallet = EthereumWallet::from(signer);

        let provider = ProviderBuilder::new()
            .with_recommended_fillers()
            .wallet(wallet)
            .on_http(self.rpc_url.parse().context("invalid RPC URL")?);

        let addr: Address = verifier_addr
            .parse()
            .context("invalid verifier address")?;

        // ABI-encode the function call
        let call_data: Bytes = updateCommitmentCall {
            _commitment: commitment_bytes.into(),
            _nonce: nonce,
        }
        .abi_encode()
        .into();

        let tx = TransactionRequest::default()
            .to(addr)
            .input(call_data.into());

        let pending = provider
            .send_transaction(tx)
            .await
            .context("failed to send commitment transaction")?;

        let tx_hash = *pending.tx_hash();
        log::info!("Commitment TX sent: {:#x}", tx_hash);

        pending
            .watch()
            .await
            .context("failed waiting for commitment TX confirmation")?;

        log::info!("Commitment TX confirmed: {:#x}", tx_hash);
        Ok(tx_hash)
    }

    /// Returns the current block number.
    pub async fn get_block_number(&self) -> Result<u64> {
        let provider = ProviderBuilder::new()
            .on_http(self.rpc_url.parse().context("invalid RPC URL")?);
        provider
            .get_block_number()
            .await
            .context("eth_blockNumber failed")
    }
}

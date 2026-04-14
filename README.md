# Arc-Hook (HashKey Testnet)

Private whitelist-gated swap flow for a Uniswap v4-style hook setup on HashKey testnet, powered by an off-chain KZG prover.

## Overview

This implementation uses:

- `WhitelistRegistry` for admin-managed whitelist entries.
- `WhitelistVerifier` for commitment storage and proof verification.
- `KZGWhitelistHook` to gate swaps in `beforeSwap`.
- Rust `kzg-prover` service to watch registry events, recompute commitments, and serve `/proof/:address`.

Current state is demo-focused and working for:

- on-chain whitelist updates
- prover ingestion of events
- commitment recomputation
- proof generation for whitelisted addresses

## Current HashKey Deployments

- `WhitelistVerifier`: `0xe279D884df66B927aEFE561Fcdf59543b4032b86`
- `KZGWhitelistHook`: `0x6c3249fC5e78F489E234cF2C3c28E337bCA3c080`
- `WhitelistRegistry`: `0xA1506fd6a7185Da771D39ba15074c98A7264C9b5`
- `ProverTrigger`: `0xD5Ec6712Db88253D2C14fA370a84972A501477bc`

## Architecture

1. Admin adds/removes address in `WhitelistRegistry`.
2. Rust prover polls `WhitelistUpdated` logs from registry.
3. Prover updates local DB, recomputes KZG commitment, stores state.
4. Prover serves `hook_data` via `GET /proof/:address`.
5. Swap caller provides `hook_data` to hook path.
6. `KZGWhitelistHook` calls `WhitelistVerifier.verify(...)` before swap.

## Repository Structure

```text
Arc-Hook/
├── src/
│   ├── WhitelistRegistry.sol
│   ├── WhitelistVerifier.sol
│   ├── KZGWhitelistHook.sol
│   ├── ProverTrigger.sol
│   └── interfaces/
├── script/
├── test/
├── frontend/
└── kzg-prover/
```

## Prerequisites

- Foundry (`forge`, `cast`)
- Rust + Cargo
- Node.js + npm

## Local Setup

### 1) Solidity dependencies

If needed:

```bash
git clone https://github.com/foundry-rs/forge-std.git lib/forge-std
git clone --recurse-submodules https://github.com/Uniswap/v4-periphery.git lib/v4-periphery
```

### 2) Prover config

Create `kzg-prover/.env`:

```env
RPC_URL=https://testnet.hsk.xyz
REGISTRY_ADDRESS=0xA1506fd6a7185Da771D39ba15074c98A7264C9b5
TRIGGER_ADDRESS=0xD5Ec6712Db88253D2C14fA370a84972A501477bc
VERIFIER_ADDRESS=0xe279D884df66B927aEFE561Fcdf59543b4032b86
PROVER_PRIVATE_KEY=0x...
DB_PATH=./prover.db
SERVER_PORT=8081
START_BLOCK=26534000
```

Run prover:

```bash
cd kzg-prover
RUST_LOG=info cargo run --release --bin kzg-prover
```

### 3) Frontend config

Create `frontend/.env.local`:

```env
NEXT_PUBLIC_CHAIN_ID=133
NEXT_PUBLIC_CHAIN_NAME=HashKey Testnet
NEXT_PUBLIC_CHAIN_RPC_URL=https://testnet.hsk.xyz
NEXT_PUBLIC_EXPLORER_BASE_URL=https://hashkey.blockscout.com
NEXT_PUBLIC_PROVER_API_BASE=http://127.0.0.1:8081

NEXT_PUBLIC_REGISTRY_ADDRESS=0xA1506fd6a7185Da771D39ba15074c98A7264C9b5
NEXT_PUBLIC_VERIFIER_ADDRESS=0xe279D884df66B927aEFE561Fcdf59543b4032b86
NEXT_PUBLIC_HOOK_ADDRESS=0x6c3249fC5e78F489E234cF2C3c28E337bCA3c080
NEXT_PUBLIC_TRIGGER_ADDRESS=0xD5Ec6712Db88253D2C14fA370a84972A501477bc

# Set these to your HashKey deployment addresses
NEXT_PUBLIC_POOL_MANAGER=0x...
NEXT_PUBLIC_SWAP_ROUTER=0x...
NEXT_PUBLIC_TOKEN0=0x...
NEXT_PUBLIC_TOKEN1=0x...
```

Run frontend:

```bash
cd frontend
npm install
npm run dev
```

## CLI Test Flow

### 1) Add whitelist user on-chain

```bash
RPC_URL="https://testnet.hsk.xyz"
REGISTRY="0xA1506fd6a7185Da771D39ba15074c98A7264C9b5"
TEST_USER="0x7aeCb231A471f0047f7d9Dc9eb968f983657cD24"
OWNER_PK="0x<registry_owner_private_key>"

cast send "$REGISTRY" "addAddress(address)" "$TEST_USER" \
  --rpc-url "$RPC_URL" \
  --private-key "$OWNER_PK"
```

Verify:

```bash
cast call "$REGISTRY" "isWhitelisted(address)(bool)" "$TEST_USER" --rpc-url "$RPC_URL"
```

### 2) Check prover status

```bash
curl -s http://127.0.0.1:8081/status
```

Expected:

- `whitelisted_count` >= 1
- `latest_commitment` not `0x00`

### 3) Generate proof

```bash
curl -s "http://127.0.0.1:8081/proof/$TEST_USER"
```

Expected:

- JSON with `hook_data`

### 4) Verify proof on-chain

```bash
HOOK_DATA=$(curl -s "http://127.0.0.1:8081/proof/$TEST_USER" | jq -r '.hook_data')
cast call 0xe279D884df66B927aEFE561Fcdf59543b4032b86 "verify(address,bytes)(bool)" "$TEST_USER" "$HOOK_DATA" --rpc-url "$RPC_URL"
```

Expected:

- `true`

## Notes

- Hook address is mined to satisfy `BEFORE_SWAP` flag.
- Prover now polls `WhitelistUpdated` directly from the registry on HashKey.
- `/status.latest_block` may show `0` due to key naming mismatch in current status lookup; this does not block proof generation.

## Security Status

This is currently a demo-grade implementation:

- address binding checks are implemented
- full pairing verification in `WhitelistVerifier` remains TODO
- development SRS setup is not production hardened

Do not treat this as production-ready cryptographic enforcement without completing pairing checks and full audit hardening.

## License

MIT

# HashKey Testnet Demo Checklist

## 1) Contracts (already deployed)

- `WhitelistVerifier`: `0xe279D884df66B927aEFE561Fcdf59543b4032b86`
- `KZGWhitelistHook`: `0x6c3249fC5e78F489E234cF2C3c28E337bCA3c080`

## 2) Prover setup

```bash
cd kzg-prover
cp .env.example .env
```

Fill in:
- `REGISTRY_ADDRESS`
- `TRIGGER_ADDRESS`
- `PROVER_PRIVATE_KEY` (must match `proverEOA` set in verifier constructor)

Run:

```bash
RUST_LOG=info cargo run --release
```

Health check:

```bash
curl http://127.0.0.1:8080/status
```

## 3) Frontend setup

```bash
cd frontend
cp .env.local.example .env.local
npm install
npm run dev
```

Set at least:
- `NEXT_PUBLIC_REGISTRY_ADDRESS`
- `NEXT_PUBLIC_POOL_MANAGER`
- `NEXT_PUBLIC_SWAP_ROUTER`
- `NEXT_PUBLIC_TOKEN0`
- `NEXT_PUBLIC_TOKEN1`

## 4) Demo flow

1. Connect wallet on HashKey testnet.
2. In admin panel, add a demo address to whitelist.
3. Wait for prover to sync nonce to verifier.
4. Confirm proof endpoint returns `hook_data` for that address:
   - `GET /proof/<address>`
5. Execute swap from private swap panel.

## 5) Common checks

- If swap is blocked: ensure `hookData` exists and wallet is whitelisted.
- If proof is missing: check prover logs and registry/trigger addresses.
- If chain mismatch warning appears: verify `NEXT_PUBLIC_CHAIN_ID=133`.

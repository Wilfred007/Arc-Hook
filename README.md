# 🔐 UniswapV4 KZG Privacy Whitelist

> **Private, compliance-ready whitelisting for Uniswap v4 pools using multilinear KZG commitments and the Reactive Network.**

A trader can prove they are on an institutional whitelist and execute a swap — without their address ever appearing in a public on-chain list. Nobody can front-run them. Nobody can tag their wallet. Compliance is preserved without exposure.

---
0x052faB7c34011dA32d117d8354bdEC6b0Ca28d6e

## Table of Contents

1. [Overview](#overview)
2. [The Problem We Solve](#the-problem-we-solve)
3. [How It Works — High-Level](#how-it-works--high-level)
4. [Architecture](#architecture)
   - [Component Map](#component-map)
   - [End-to-End Data Flow](#end-to-end-data-flow)
5. [Cryptography Deep-Dive](#cryptography-deep-dive)
   - [Multilinear KZG Commitments](#multilinear-kzg-commitments)
   - [The Whitelist Indicator Polynomial](#the-whitelist-indicator-polynomial)
   - [Address Encoding on the Boolean Hypercube](#address-encoding-on-the-boolean-hypercube)
   - [Proof Generation](#proof-generation)
   - [On-Chain Verification](#on-chain-verification)
   - [Structured Reference String (SRS)](#structured-reference-string-srs)
6. [Smart Contracts](#smart-contracts)
   - [WhitelistRegistry](#whitelistregistry)
   - [KZGWhitelistRSC (Reactive Smart Contract)](#kzgwhitelistrsc-reactive-smart-contract)
   - [ProverTrigger](#provertrigger)
   - [WhitelistVerifier](#whitelistverifier)
   - [KZGWhitelistHook](#kzgwhitelisthook)
   - [IWhitelistVerifier Interface](#iwhitelistverifier-interface)
7. [The Reactive Network Integration](#the-reactive-network-integration)
8. [Off-Chain KZG Prover](#off-chain-kzg-prover)
   - [Architecture](#prover-architecture)
   - [Listener](#listener)
   - [REST API Server](#rest-api-server)
   - [Local Database](#local-database)
   - [KZG Modules](#kzg-modules)
9. [Supported Networks](#supported-networks)
10. [Repository Structure](#repository-structure)
11. [Prerequisites](#prerequisites)
12. [Installation](#installation)
13. [Configuration](#configuration)
14. [Deployment Guide](#deployment-guide)
    - [Step 1: Deploy to Unichain Sepolia](#step-1-deploy-to-unichain-sepolia)
    - [Step 2: Deploy the Reactive Smart Contract](#step-2-deploy-the-reactive-smart-contract)
    - [Step 3: Run the KZG Prover](#step-3-run-the-kzg-prover)
    - [Step 4: Register a Pool](#step-4-register-a-pool)
15. [Testing](#testing)
    - [Solidity Tests](#solidity-tests)
    - [Rust Prover Tests](#rust-prover-tests)
16. [API Reference](#api-reference)
17. [Hook Data Format](#hook-data-format)
18. [Security Considerations](#security-considerations)
19. [Production Checklist](#production-checklist)
20. [Troubleshooting](#troubleshooting)
21. [Contributing](#contributing)
22. [License](#license)

---

## Overview

**UniswapV4 KZG Privacy Whitelist** is a system that lets pool administrators maintain a whitelist of approved addresses (e.g., KYC-verified institutional traders) while keeping those addresses completely private on-chain.

Instead of storing raw addresses in a public mapping, the system:

1. Represents the whitelist as a **multilinear polynomial** over the boolean hypercube `{0,1}²⁰`.
2. Commits to this polynomial using a **KZG commitment** — a single 48-byte BLS12-381 G1 point.
3. Only the commitment is published on-chain. No individual address is ever revealed.
4. A whitelisted trader fetches a **KZG opening proof** from an off-chain prover REST API, passes it as `hookData` in their swap transaction, and the Uniswap v4 hook verifies the proof on-chain.

The commit → prove → verify cycle means:

- Observers see a single cryptographic fingerprint (48 bytes), not a list of addresses.
- Proofs are **address-specific**: a proof for Alice cannot be replayed by Bob.
- When the whitelist changes, the off-chain prover automatically recomputes and publishes a new commitment.

---

## The Problem We Solve

Regulated DeFi pools need to restrict access to approved participants. The naive solution — a public `mapping(address => bool)` — creates a **privacy catastrophe**:

| Problem                          | Impact                                                                |
| -------------------------------- | --------------------------------------------------------------------- |
| **Publicly revealed identities** | Whale wallets are tagged the moment they are added                    |
| **Front-running**                | MEV bots see whitelisted addresses and trade ahead of them            |
| **Competitive intelligence**     | Competitors track which funds enter/exit which pools                  |
| **Targeted attacks**             | Known large wallets become targets for phishing or governance attacks |

This project solves all of these by replacing the public list with a **zero-knowledge-friendly cryptographic commitment**. Membership can be proven, but membership cannot be enumerated.

---

## How It Works — High-Level

```
ADMIN FLOW (off-chain & cross-chain)
──────────────────────────────────────────────────────────────────────────────
Admin calls WhitelistRegistry.addAddress(alice)      ← Origin chain (Unichain)
           │
           └─ emits WhitelistUpdated(alice, true, nonce)
                      │
                      ▼
           KZGWhitelistRSC (Reactive Network)  ← listens to the event
           emits Callback(destinationChain, ProverTrigger, ...)
                      │
                      ▼
           ProverTrigger.onCallback(alice, true, nonce)  ← Destination chain
           emits TriggerReceived
                      │
                      ▼
           KZG Prover (Rust off-chain service)  ← watches TriggerReceived
           recomputes commitment & calls WhitelistVerifier.updateCommitment()

SWAP FLOW (user)
──────────────────────────────────────────────────────────────────────────────
Alice's frontend calls GET /proof/0xAliceAddress  ← Prover REST API
           │
           └─ returns ABI-encoded hookData (proof)
                      │
                      ▼
           Alice submits swap on Uniswap v4 with hookData
                      │
                      ▼
           KZGWhitelistHook.beforeSwap() called by PoolManager
           verifier.verify(alice, hookData) → true  ← Swap allowed ✓
```

---

## Architecture

### Component Map

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         UNICHAIN SEPOLIA (EVM)                          │
│                                                                         │
│  ┌────────────────────┐   WhitelistUpdated   ┌─────────────────────┐   │
│  │  WhitelistRegistry │ ──────────────────▶  │  KZGWhitelistRSC    │   │
│  │  (Ownable)         │                      │  (Reactive Network) │   │
│  └────────────────────┘                      └─────────────────────┘   │
│                                                         │               │
│  ┌────────────────────┐   Callback            ┌─────────────────────┐  │
│  │  ProverTrigger     │ ◀──────────────────── │  Reactive Callback  │  │
│  │  (onCallback)      │                       │  Proxy              │  │
│  └────────────────────┘                       └─────────────────────┘  │
│            │ TriggerReceived                                            │
│            ▼                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                    KZG PROVER (Rust off-chain)                     │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────────────────┐│ │
│  │  │ Listener │  │  SQLite  │  │  KZG Lib │  │ Actix-web REST API ││ │
│  │  │  (logs)  │  │  (state) │  │  (math)  │  │  /proof/:addr      ││ │
│  │  └──────────┘  └──────────┘  └──────────┘  └────────────────────┘│ │
│  └────────────────────────────────────────────────────────────────────┘ │
│            │ updateCommitment()                                         │
│            ▼                                                            │
│  ┌────────────────────┐   verify()          ┌─────────────────────────┐│
│  │  WhitelistVerifier │ ◀ ─ ─ ─ ─ ─ ─ ─ ─  │  KZGWhitelistHook      ││
│  │  (KZG commitment)  │                     │  (.beforeSwap)         ││
│  └────────────────────┘                     └─────────────────────────┘│
│                                                        ▲               │
│                                                        │ hookData       │
│                                               ┌────────────────────┐   │
│                                               │  User / Frontend   │   │
│                                               └────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

### End-to-End Data Flow

| Step | Actor            | Action                                                 | Result                                  |
| ---- | ---------------- | ------------------------------------------------------ | --------------------------------------- |
| 1    | Admin            | `registry.addAddress(alice)`                           | `WhitelistUpdated` event emitted        |
| 2    | Reactive Network | RSC listens, encodes callback                          | Cross-chain message dispatched          |
| 3    | Reactive Proxy   | Calls `trigger.onCallback(alice, true, nonce)`         | `TriggerReceived` event emitted         |
| 4    | KZG Prover       | Detects `TriggerReceived`, updates local SQLite DB     | New address added to prover state       |
| 5    | KZG Prover       | Recomputes multilinear polynomial + KZG commitment     | New 48-byte G1 point computed           |
| 6    | KZG Prover       | Calls `verifier.updateCommitment(commitment, nonce)`   | Commitment stored on-chain              |
| 7    | Alice            | `GET /proof/0xAlice` from Prover API                   | `hookData` (ABI-encoded proof) returned |
| 8    | Alice            | Submits Uniswap v4 swap with `hookData`                | Swap transaction sent                   |
| 9    | PoolManager      | Calls `hook.beforeSwap(alice, ..., hookData)`          | Hook intercepts swap                    |
| 10   | Hook             | Calls `verifier.verify(alice, hookData)`               | Proof checked                           |
| 11   | Verifier         | Validates `claimedValue == 1`, checks `evalPoint` bits | Returns `true`                          |
| 12   | PoolManager      | Swap proceeds                                          | Alice trades, all private ✓             |

---

## Cryptography Deep-Dive

### Multilinear KZG Commitments

A **multilinear polynomial** is a function `f: {0,1}^n → F` where each input variable appears at most to the first power. The whitelist of up to 2^n addresses is encoded as the evaluation table of such a polynomial.

A **KZG commitment** to a polynomial is a single group element `C = [f(τ)]₁` in the elliptic curve group, where `τ` is a secret scalar from a trusted setup. The commitment has two critical properties:

- **Binding**: Once published, `C` can only be consistent with one polynomial `f`.
- **Hiding** (informally): Without the SRS trapdoor, you cannot recover `f` from `C`.

### The Whitelist Indicator Polynomial

The whitelist is encoded as the evaluation table of a multilinear polynomial over `{0,1}^20`:

```
f: {0,1}^20 → {0, 1}

f(x_0, x_1, ..., x_19) = 1   if the address whose hypercube index = (x_0,...,x_19) is whitelisted
                        = 0   otherwise
```

The table has `2^20 = 1,048,576` entries. In practice, only whitelisted addresses have a `1`; everything else is `0`.

### Address Encoding on the Boolean Hypercube

Each Ethereum address is mapped to a unique point on the `{0,1}^20` hypercube using a **deterministic hash**:

```rust
// Rust (encoding.rs):
let hash = keccak256(abi.encodePacked(addr));
bit[i] = (uint256(hash) >> i) & 1;   // bit i, counting from LSB
```

```solidity
// Solidity (WhitelistVerifier.sol):
bytes32 hash = keccak256(abi.encodePacked(addr));
uint256 bit = (uint256(hash) >> i) & 1;
```

Both sides use **the same bit extraction logic**, so the prover's evaluation point always matches what the verifier expects. An address cannot claim a different point than its own — the evalPoint check **binds the proof to the sender**.

### Proof Generation

The prover generates a **multilinear opening proof** using the **fold-and-peel** (tensor product) protocol:

```
For i = 0 to n-1:
  1. Compute quotient polynomial: q_i[j] = f_i(1,j) - f_i(0,j)
  2. Commit to q_i: Q_i = commit(q_i, sub_srs_i)   ← one G1 point per dimension
  3. Fold table: f_{i+1}[j] = (1 - z_i)*f_i(0,j) + z_i*f_i(1,j)

After n rounds: f_n has one entry = f(z_0,...,z_{n-1}) (the claimed evaluation)
```

The output is `n = 20` G1 quotient commitments, each 48 bytes when compressed.

### On-Chain Verification

The verifier performs two checks:

1. **Evaluation check**: `claimedValue == 1` (the polynomial evaluates to 1 → the address is whitelisted).
2. **Binding check**: The `evalPoint` matches `keccak256(sender)` bit-by-bit (the proof is bound to this exact sender).
3. **Pairing check** _(production TODO)_: For each dimension `i`:
   ```
   e(Q_i, [τ]₂ - [z_i]₂) == e(C_{i-1} - C_i, [1]₂)
   ```
   This requires the [EIP-2537](https://eips.ethereum.org/EIPS/eip-2537) BLS12-381 precompile (`0x0f`) and a network that supports it.

> **⚠️ Current Status**: In the development version, the pairing check is **not yet implemented**. The evalPoint binding check IS implemented and prevents address spoofing, but a sophisticated attacker could forge `quotientCommitments`. See [Production Checklist](#production-checklist).

### Structured Reference String (SRS)

The SRS is a vector of group elements `[G₁·τ⁰, G₁·τ¹, ..., G₁·τ^(2ⁿ-1)]` generated from a trusted setup ceremony.

In development, a fixed `τ = 7` is used (the discrete log is known — `srs.rs`). **For production, replace with outputs from a real trusted setup** (e.g., the Ethereum KZG ceremony `.ptau` file).

```rust
// srs.rs — development constant (DO NOT use in production)
let tau = Fr::from_u64(7);
```

---

## Smart Contracts

All contracts are written in Solidity `^0.8.26`, compiled with `solc 0.8.26`, `EVM Cancun`, and `via_ir = true` for maximum optimization.

### WhitelistRegistry

**File**: [`src/WhitelistRegistry.sol`](src/WhitelistRegistry.sol)  
**Chain**: Origin chain (Unichain Sepolia)

The admin-facing entry point. Maintains a plain `mapping(address => bool)` (not privacy-critical) and emits events that drive the entire system.

```solidity
contract WhitelistRegistry is Ownable {
    event WhitelistUpdated(address indexed addr, bool added, uint256 nonce);

    mapping(address => bool) public isWhitelisted;
    uint256 public nonce;

    function addAddress(address addr) external onlyOwner { ... }
    function removeAddress(address addr) external onlyOwner { ... }
}
```

| Function              | Access      | Description                                                |
| --------------------- | ----------- | ---------------------------------------------------------- |
| `addAddress(addr)`    | `onlyOwner` | Adds `addr` to the registry, increments nonce, emits event |
| `removeAddress(addr)` | `onlyOwner` | Removes `addr`, increments nonce, emits event              |

> **Key insight**: The `WhitelistRegistry` mapping IS public, but it lives on the origin chain. The privacy guarantee lives in the destination chain's `WhitelistVerifier`, which stores only the commitment — not the addresses.

---

### KZGWhitelistRSC (Reactive Smart Contract)

**File**: [`src/reactive/KZGWhitelistRSC.sol`](src/reactive/KZGWhitelistRSC.sol)  
**Chain**: Reactive Network (Lasna Testnet / Mainnet)

A **Reactive Smart Contract** (RSC) that subscribes to `WhitelistUpdated` events on the origin chain and relays them to a destination chain via the Reactive Network's callback mechanism.

```solidity
contract KZGWhitelistRSC is IReactive {
    function react(LogEntry calldata log) external override {
        // Parse addr + added + nonce from the log
        // Emit Callback(..., ProverTrigger.onCallback.selector, ...)
    }
}
```

The `Callback` event instructs the Reactive Network executor to call `ProverTrigger.onCallback()` on the destination chain with `200,000` gas.

**Constructor parameters:**

| Parameter             | Description                                                |
| --------------------- | ---------------------------------------------------------- |
| `_originChainId`      | Chain ID of the origin (e.g., `1301` for Unichain Sepolia) |
| `_registryAddress`    | Address of `WhitelistRegistry` on origin                   |
| `_destinationChainId` | Chain ID of the destination                                |
| `_triggerAddress`     | Address of `ProverTrigger` on destination                  |

---

### ProverTrigger

**File**: [`src/ProverTrigger.sol`](src/ProverTrigger.sol)  
**Chain**: Destination chain (same as Unichain Sepolia in this setup)

The on-chain bridge between the Reactive Network and the off-chain prover. It receives cross-chain callbacks and emits events that the Rust prover watches.

```solidity
contract ProverTrigger is Ownable {
    event TriggerReceived(address indexed addr, bool added, uint256 nonce);

    function onCallback(address addr, bool added, uint256 nonce) external {
        if (msg.sender != reactiveCallbackProxy) revert Unauthorized();
        emit TriggerReceived(addr, added, nonce);
    }
}
```

Only the Reactive Network's **callback proxy** address can call `onCallback()`. This prevents unauthorized triggering.

---

### WhitelistVerifier

**File**: [`src/WhitelistVerifier.sol`](src/WhitelistVerifier.sol)  
**Chain**: Destination chain (same as Uniswap v4 pool)

The heart of the on-chain privacy system. Stores the KZG commitment to the whitelist polynomial and verifies membership proofs.

```solidity
contract WhitelistVerifier is Ownable, IWhitelistVerifier {
    bytes public commitment;    // 48-byte compressed G1 point
    uint64 public lastNonce;    // Monotonic — prevents replay of stale commitments
    address public proverEOA;   // Only this EOA may update the commitment

    function updateCommitment(bytes calldata _commitment, uint64 _nonce) external { ... }
    function verify(address sender, bytes calldata hookData) external pure returns (bool) { ... }
}
```

**Proof verification logic (`verify`):**

```solidity
function verify(address sender, bytes calldata hookData) external pure returns (bool) {
    (uint256 claimedValue, uint256[20] memory evalPoint, bytes[20] memory quotientCommitments)
        = abi.decode(hookData, (uint256, uint256[20], bytes[20]));

    if (claimedValue != 1) return false;           // Must be whitelisted
    if (!_verifyEvalPoint(sender, evalPoint)) return false;  // Must match sender's address
    // Pairing check: TODO (requires EIP-2537)
    return true;
}
```

**Events:**

| Event               | Parameters                       | Emitted when                    |
| ------------------- | -------------------------------- | ------------------------------- |
| `CommitmentUpdated` | `bytes commitment, uint64 nonce` | Prover submits a new commitment |

**Errors:**

| Error                  | Condition                         |
| ---------------------- | --------------------------------- |
| `UnauthorizedProver()` | Caller is not `proverEOA`         |
| `StaleNonce()`         | Provided nonce ≤ `lastNonce`      |
| `InvalidProof()`       | Reserved for future pairing check |

---

### KZGWhitelistHook

**File**: [`src/KZGWhitelistHook.sol`](src/KZGWhitelistHook.sol)  
**Chain**: Destination chain (same as Uniswap v4 pool)

The Uniswap v4 hook that gates swap access. It implements the full `IHooks` interface and activates **only** the `beforeSwap` permission.

```solidity
contract KZGWhitelistHook is IHooks {
    IPoolManager public immutable manager;
    IWhitelistVerifier public immutable verifier;

    function beforeSwap(
        address sender,
        PoolKey calldata,
        SwapParams calldata,
        bytes calldata hookData
    ) external view override onlyManager returns (bytes4, BeforeSwapDelta, uint24) {
        if (!verifier.verify(sender, hookData)) {
            revert NotWhitelisted(sender);
        }
        return (IHooks.beforeSwap.selector, BeforeSwapDelta.wrap(0), 0);
    }
}
```

**Hook permissions:**

| Hook         | Enabled |
| ------------ | ------- |
| `beforeSwap` | ✅ Yes  |
| All others   | ❌ No   |

**Important**: Per Uniswap v4's hook address encoding scheme, the deployed hook address must have the **`BEFORE_SWAP_FLAG`** bit set in its address. The deployment script checks for this and warns if it's missing. In production, use a **CREATE2 factory** to mine a valid address.

---

### IWhitelistVerifier Interface

**File**: [`src/interfaces/IWhitelistVerifier.sol`](src/interfaces/IWhitelistVerifier.sol)

A minimal interface that decouples the hook from the verifier implementation, enabling upgrades.

```solidity
interface IWhitelistVerifier {
    function verify(address sender, bytes calldata hookData) external returns (bool);
}
```

---

## The Reactive Network Integration

The [Reactive Network](https://reactive.network) enables **event-driven cross-chain automation** without requiring a centralized relayer. RSCs are regular Solidity contracts deployed on the Reactive Network that can:

1. Subscribe to on-chain events from any chain.
2. Execute business logic in `react()`.
3. Trigger callbacks on destination chains by emitting `Callback` events.

In this system:

- **Origin**: Unichain Sepolia (`chainId = 1301`) — where admins manage the `WhitelistRegistry`.
- **RSC**: Lives on the Reactive Network (Lasna or Mainnet).
- **Destination**: Unichain Sepolia — where `ProverTrigger` receives the callback.

This cross-chain relay ensures the off-chain prover is notified of whitelist changes without manual intervention or a centralized bot.

---

## Off-Chain KZG Prover

The prover is a **Rust async service** built with Tokio, Actix-web, and the `blst` BLS12-381 library.

### Prover Architecture

```
main.rs
 ├── loads .env / CLI config
 ├── opens SQLite database (db.rs)
 ├── loads SRS into memory (2^20 G1 points)
 ├── tokio::spawn → listener::start_listener()   [background task]
 └── server::start_server()                       [blocking main task]
```

### Listener

**File**: [`kzg-prover/src/listener.rs`](kzg-prover/src/listener.rs)

Runs in a background Tokio task. Every **7 seconds**, it:

1. Fetches new `WhitelistUpdated` logs from the `WhitelistRegistry` on-chain.
2. Applies `add` / `remove` operations to the local SQLite whitelist table.
3. Recomputes the full `2^20`-entry evaluation table using `encoding::build_table()`.
4. Computes the new KZG commitment via `commit::commit()`.
5. Persists the new commitment and nonce to the local database.
6. If `PROVER_PRIVATE_KEY` and `VERIFIER_ADDRESS` are configured, submits the new commitment on-chain using `chain::ChainClient`.

**Config (optional)**:  
If `PROVER_PRIVATE_KEY` / `VERIFIER_ADDRESS` are not set, the prover runs in **observe-only mode**: it computes commitments locally but does not submit them on-chain.

### REST API Server

**File**: [`kzg-prover/src/server.rs`](kzg-prover/src/server.rs)

Built with **Actix-web 4**, serves proof requests to frontend clients. CORS is fully open (allow any origin).

#### `GET /status`

Returns the current prover state.

```json
{
  "latest_block": 12345678,
  "latest_commitment": "a1b2c3...",
  "whitelisted_count": 42
}
```

#### `GET /proof/:address`

Generates and returns the `hookData` for a whitelisted address.

**Success** (HTTP 200):

```json
{
  "address": "0xd8da6bf26964af9d7eed9e03e53415d37aa96045",
  "hook_data": "0x0000000000000000000000000000000000000000000000000000000000000001..."
}
```

**Not whitelisted** (HTTP 404):

```json
{
  "error": "Address 0x... is not whitelisted"
}
```

The `hook_data` field is the ABI-encoded proof that must be passed as `hookData` in the Uniswap v4 swap transaction.

### Local Database

**File**: [`kzg-prover/src/db.rs`](kzg-prover/src/db.rs)

Uses **SQLite** via `rusqlite` with two tables:

**`whitelist` table:**
| Column | Type | Description |
|---|---|---|
| `address` | `TEXT PRIMARY KEY` | Ethereum address (hex string) |
| `added_at_nonce` | `INTEGER` | Nonce value at time of addition |

**`sync_state` table:**
| Key | Description |
|---|---|
| `last_block` | Last processed block number |
| `last_commitment` | Latest commitment hex string |
| `last_nonce` | Latest nonce value |

The database provides **crash recovery**: upon restart, the prover resumes from the last processed block rather than replaying all history.

### KZG Modules

All cryptographic logic lives in [`kzg-prover/src/kzg/`](kzg-prover/src/kzg/):

#### `field.rs` — BLS12-381 Field Arithmetic

Wrappers around `blst` for scalar field elements (`Fr`) and G1 curve points (`G1`).

Key types:

- `Fr` — BLS12-381 scalar field element
- `G1` — BLS12-381 G1 group element with `.mul()`, `.add()`, `.compress()` methods

#### `srs.rs` — Structured Reference String

Generates the powers-of-tau: `[G1·τ⁰, G1·τ¹, ..., G1·τ^(2²⁰-1)]`.

> **Development**: uses `τ = 7` (weak, discrete log known).  
> **Production**: Load from a real trusted setup `.ptau` file.

#### `encoding.rs` — Address-to-Hypercube Mapping

```rust
pub fn address_to_hypercube_bits(address: &str) -> Vec<bool>
pub fn build_table(whitelisted_addresses: &[String], num_vars: usize) -> Vec<Fr>
```

- `address_to_hypercube_bits`: Deterministically maps an Ethereum address to its 20-bit coordinate on the boolean hypercube using `keccak256`.
- `build_table`: Builds the `2^n`-entry evaluation table; sets `table[idx] = Fr::one()` for each whitelisted address's corresponding index.

#### `commit.rs` — KZG Commitment

```rust
pub fn commit(table: &[Fr], srs: &[G1]) -> G1
// Returns: Σ table[i] * srs[i]  (inner product in G1)
```

Computes the polynomial commitment as the multi-scalar multiplication of the evaluation table against the SRS.

#### `proof.rs` — Proof Generation and ABI Encoding

```rust
pub fn generate_proof(point: &[bool], table: &[Fr], srs: &[G1]) -> Vec<G1>
pub fn evaluate(point: &[bool], table: &[Fr]) -> Fr
pub fn encode_hookdata(point: &[bool], quotient_commitments: &[G1]) -> Vec<u8>
```

- `generate_proof`: Runs the fold-and-peel multilinear opening protocol, producing `n` G1 quotient commitments.
- `evaluate`: Evaluates the polynomial at a boolean point by repeated folding. Used for testing.
- `encode_hookdata`: ABI-encodes `(uint256 claimedValue, uint256[20] evalPoint, bytes[20] quotientCommitments)` into the exact format expected by `WhitelistVerifier.verify()`.

---

## Supported Networks

| Network          | Chain ID  | RPC URL                        | Role                 |
| ---------------- | --------- | ------------------------------ | -------------------- |
| Unichain Sepolia | `1301`    | `https://sepolia.unichain.org` | Origin & Destination |
| Reactive Lasna   | `5318007` | `https://lasna-rpc.rnk.dev/`   | Testnet RSC relay    |
| Reactive Mainnet | `1597`    | `https://mainnet-rpc.rnk.dev/` | Production RSC relay |

### Get Testnet lREACT

To obtain testnet REACT (lREACT) on Lasna, send ETH to one of the faucet contracts:

- **Etereum Sepolia**: `0x9b9BB25f1A81078C544C829c5EB7822d747Cf434`
- **Base Sepolia**: `0x2afaFD298b23b62760711756088F75B7409f5967`

Exchange rate: 1 ETH → 100 lREACT.
Max: 5 ETH per transaction.

---

## Repository Structure

```
uniwsap-v4-privacy/
│
├── foundry.toml                     # Foundry build config (Solidity 0.8.26, EVM Cancun)
├── remappings.txt                   # Solidity import remappings
├── .env.deployment.example          # Template for deployment environment variables
│
├── src/                             # Solidity smart contracts
│   ├── WhitelistRegistry.sol        # Admin entry point (origin chain)
│   ├── WhitelistVerifier.sol        # KZG commitment store + proof verifier
│   ├── KZGWhitelistHook.sol         # Uniswap v4 beforeSwap hook
│   ├── ProverTrigger.sol            # Reactive callback receiver
│   ├── interfaces/
│   │   └── IWhitelistVerifier.sol   # Verifier interface
│   └── reactive/
│       └── KZGWhitelistRSC.sol      # Reactive Network relay contract
│
├── script/                          # Foundry deployment scripts
│   ├── Deploy.s.sol                 # Local / generic deployment
│   ├── DeployUnichain.s.sol         # Unichain Sepolia deployment
│   └── DeployReactive.s.sol         # Reactive Network deployment
│
├── test/                            # Foundry tests
│   └── KZGWhitelistTest.t.sol       # Full end-to-end integration test
│
├── lib/                             # Foundry dependencies (git submodules)
│   ├── forge-std/
│   └── v4-core/
│
└── kzg-prover/                      # Off-chain Rust prover service
    ├── Cargo.toml                   # Rust dependencies
    └── src/
        ├── main.rs                  # Entry point (Tokio async runtime)
        ├── listener.rs              # On-chain event polling loop
        ├── server.rs                # Actix-web REST API
        ├── db.rs                    # SQLite persistence layer
        ├── chain.rs                 # Alloy-based chain client
        └── kzg/
            ├── mod.rs
            ├── field.rs             # BLS12-381 field / G1 types
            ├── srs.rs               # Structured Reference String
            ├── encoding.rs          # Address → hypercube encoding
            ├── commit.rs            # KZG commitment (MSM)
            └── proof.rs             # Multilinear opening proof
```

---

## Prerequisites

### Solidity / Foundry

- [Foundry](https://getfoundry.sh/) — `forge`, `cast`, `anvil`
  ```bash
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
  ```

### Rust / Cargo

- [Rust](https://rustup.rs/) stable toolchain (1.75+)
  ```bash
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
  ```

### Git Submodules

The project uses git submodules for Solidity dependencies:

```bash
git submodule update --init --recursive
```

---

## Installation

```bash
# 1. Clone the repository
git clone https://github.com/your-org/uniwsap-v4-privacy.git
cd uniwsap-v4-privacy

# 2. Initialize submodules
git submodule update --init --recursive

# 3. Build Solidity contracts
forge build

# 4. Build the Rust prover
cd kzg-prover
cargo build --release
cd ..
```

---

## Configuration

Copy the environment template and fill in your values:

```bash
cp .env.deployment.example .env
```

### Solidity Deployment Variables

| Variable                   | Description                                          | Example                        |
| -------------------------- | ---------------------------------------------------- | ------------------------------ |
| `UNICHAIN_RPC_URL`         | RPC endpoint for Unichain Sepolia                    | `https://sepolia.unichain.org` |
| `UNICHAIN_PRIVATE_KEY`     | Deployer private key (hex, with `0x` prefix)         | `0x...`                        |
| `POOL_MANAGER`             | Canonical Uniswap v4 PoolManager address on Unichain | `0x...`                        |
| `PROVER_ADDRESS`           | EOA address of the off-chain KZG prover              | `0x...`                        |
| `REACTIVE_RPC_URL`         | RPC for Reactive Network (Lasna or Mainnet)          | `https://lasna-rpc.rnk.dev/`   |
| `REACTIVE_PRIVATE_KEY`     | Private key for Reactive Network deployment          | `0x...`                        |
| `REACTIVE_SYSTEM_CONTRACT` | Reactive Network system contract address             | `0x0000...fffFfF`              |
| `ORIGIN_CHAIN_ID`          | Chain ID of origin (Unichain Sepolia)                | `1301`                         |
| `DEST_CHAIN_ID`            | Chain ID of destination                              | `1301`                         |

### Prover Service Variables

| Variable             | Required | Description                                                           |
| -------------------- | -------- | --------------------------------------------------------------------- |
| `RPC_URL`            | ✅       | RPC URL for the chain the prover watches                              |
| `REGISTRY_ADDRESS`   | ✅       | Deployed `WhitelistRegistry` address                                  |
| `TRIGGER_ADDRESS`    | ✅       | Deployed `ProverTrigger` address                                      |
| `PROVER_PRIVATE_KEY` | ❌       | If set, enables on-chain commitment submission                        |
| `VERIFIER_ADDRESS`   | ❌       | `WhitelistVerifier` address (required if `PROVER_PRIVATE_KEY` is set) |
| `DB_PATH`            | ❌       | SQLite file path (default: `prover.db`)                               |
| `SERVER_PORT`        | ❌       | API server port (default: `8080`)                                     |

---

## Deployment Guide

### Step 1: Deploy to Unichain Sepolia

```bash
source .env

forge script script/DeployUnichain.s.sol:DeployUnichain \
  --rpc-url $UNICHAIN_RPC_URL \
  --private-key $UNICHAIN_PRIVATE_KEY \
  --broadcast \
  --verify
```

This deploys:

1. `WhitelistRegistry` — admin entry point
2. `WhitelistVerifier` — KZG commitment store
3. `ProverTrigger` — Reactive callback receiver
4. `KZGWhitelistHook` — Uniswap v4 hook

> **⚠️ Hook Address**: The hook address **must** have the `BEFORE_SWAP_FLAG` bit set. The script will print a warning if it doesn't. In production, use a CREATE2 factory to mine a valid address. The script shows the address so you can verify.

Save the deployed addresses — you will need them for subsequent steps.

### Step 2: Deploy the Reactive Smart Contract

```bash
forge script script/DeployReactive.s.sol \
  --rpc-url $REACTIVE_RPC_URL \
  --private-key $REACTIVE_PRIVATE_KEY \
  --broadcast
```

The RSC is initialized with the origin registry address, chain IDs, and destination trigger address.

### Step 3: Run the KZG Prover

Create a `.env` file in `kzg-prover/`:

```env
RPC_URL=https://sepolia.unichain.org
REGISTRY_ADDRESS=0x<WhitelistRegistry address>
TRIGGER_ADDRESS=0x<ProverTrigger address>
PROVER_PRIVATE_KEY=0x<prover key>
VERIFIER_ADDRESS=0x<WhitelistVerifier address>
DB_PATH=./prover.db
SERVER_PORT=8080
```

Run the prover:

```bash
cd kzg-prover
RUST_LOG=info cargo run --release
```

Expected startup output:

```
╔══════════════════════════════════╗
║       KZG Whitelist Prover        ║
╚══════════════════════════════════╝
INFO  RPC:              https://sepolia.unichain.org
INFO  Registry:         0x...
INFO  Trigger:          0x...
INFO  DB:               ./prover.db
INFO  API Port:         8080
INFO  Chain submission: enabled
INFO  Loading SRS (2^20 points)…
INFO  SRS loaded.
INFO  Starting listener from block 0
```

### Step 4: Register a Pool

Once all contracts are deployed and the prover is running, create a Uniswap v4 pool that uses the hook address:

```bash
cast send $POOL_MANAGER "initialize((address,address,uint24,int24,address),uint160,bytes)" \
  "($TOKEN0,$TOKEN1,$FEE,$TICK_SPACING,$HOOK_ADDRESS)" \
  "$INITIAL_SQRT_PRICE" \
  "0x" \
  --rpc-url $UNICHAIN_RPC_URL \
  --private-key $DEPLOYER_KEY
```

Then add addresses to the whitelist:

```bash
cast send $REGISTRY_ADDRESS "addAddress(address)" $ALICE_ADDRESS \
  --rpc-url $UNICHAIN_RPC_URL \
  --private-key $DEPLOYER_KEY
```

Wait ~7 seconds for the prover to detect the event and update the commitment.

---

## Testing

### Solidity Tests

```bash
# Run all Foundry tests
forge test -vvv

# Run a specific test
forge test --match-test test_whitelist_flow -vvv

# Check gas usage
forge test --gas-report

# Check code coverage
forge coverage
```

The main test file `test/KZGWhitelistTest.t.sol` covers:

1. Non-whitelisted address fails `verify()` with empty proof.
2. Admin adds address to `WhitelistRegistry`.
3. Simulated Reactive RSC callback triggers `ProverTrigger`.
4. Prover EOA updates commitment on `WhitelistVerifier`.
5. Alice generates a valid proof (with correct `evalPoint` bits for her address) and `verify()` returns `true`.
6. Bob (not whitelisted) is rejected by `KZGWhitelistHook.beforeSwap()` with `NotWhitelisted` error.
7. Alice is accepted by `KZGWhitelistHook.beforeSwap()`.

**Format code:**

```bash
forge fmt
```

**Gas snapshot:**

```bash
forge snapshot
```

### Rust Prover Tests

```bash
cd kzg-prover

# Run all tests
cargo test

# Run with output (for println! debugging)
cargo test -- --nocapture

# Run a specific test
cargo test test_evaluate_whitelisted
```

Key unit tests:

| Test                                      | Location      | Verifies                                          |
| ----------------------------------------- | ------------- | ------------------------------------------------- |
| `test_bits_length`                        | `encoding.rs` | 20 bits extracted per address                     |
| `test_same_address_same_bits`             | `encoding.rs` | Deterministic encoding                            |
| `test_different_addresses_different_bits` | `encoding.rs` | Unique encoding per address                       |
| `test_build_table_single_address`         | `encoding.rs` | Table has exactly one `1` entry                   |
| `test_build_table_empty`                  | `encoding.rs` | Empty whitelist → all-zero table                  |
| `test_evaluate_whitelisted`               | `proof.rs`    | Whitelisted address evaluates to 1                |
| `test_evaluate_not_whitelisted`           | `proof.rs`    | Non-whitelisted evaluates to 0                    |
| `test_proof_length`                       | `proof.rs`    | Proof has exactly `num_vars` quotient commitments |
| `test_srs_length`                         | `srs.rs`      | SRS has `2^num_vars` elements                     |
| `test_srs_first_element_is_generator`     | `srs.rs`      | `srs[0] = G1 * τ^0 = G1`                          |
| `test_srs_elements_differ`                | `srs.rs`      | Subsequent SRS elements are distinct              |

---

## API Reference

The Rust prover exposes a REST API at `http://localhost:8080` (or as configured by `SERVER_PORT`).

### `GET /status`

Returns the current prover state.

**Response:**

```json
{
  "latest_block": 12345678,
  "latest_commitment": "97f1d3a...",
  "whitelisted_count": 7
}
```

### `GET /proof/:address`

Generates a KZG membership proof for the given Ethereum address.

**Parameters:**

- `:address` — Ethereum address (hex, with or without `0x` prefix, case-insensitive)

**Success Response (200):**

```json
{
  "address": "0xd8da6bf26964af9d7eed9e03e53415d37aa96045",
  "hook_data": "0x0000000000000000000000000000000000000000000000000000000000000001..."
}
```

The `hook_data` field is ready to be passed directly as `hookData` in the Uniswap v4 swap call.

**Error Response (404) — Address not whitelisted:**

```json
{
  "error": "Address 0x... is not whitelisted"
}
```

---

## Hook Data Format

The `hookData` passed in swap transactions is ABI-encoded as:

```solidity
abi.encode(
    uint256 claimedValue,      // Must be 1 (whitelisted)
    uint256[20] evalPoint,     // Bit decomposition of keccak256(sender)
    bytes[20] quotientCommitments  // n=20 compressed G1 points, 48 bytes each
)
```

| Field                        | Size                | Description                                             |
| ---------------------------- | ------------------- | ------------------------------------------------------- |
| `claimedValue`               | 32 bytes            | Always `1` for a valid member proof                     |
| `evalPoint[0..19]`           | 20 × 32 = 640 bytes | First 20 bits of `keccak256(sender)` as `uint256` words |
| `quotientCommitments[0..19]` | dynamic             | 20 compressed G1 points (48 bytes each) + ABI overhead  |

Total `hookData` size: approximately **~3 KB**.

The `_verifyEvalPoint()` function in `WhitelistVerifier` performs:

```solidity
bytes32 hash = keccak256(abi.encodePacked(addr));
for (uint256 i = 0; i < 20; i++) {
    uint256 bit = (uint256(hash) >> i) & 1;
    if (evalPoint[i] != bit) return false;
}
```

This ensures the proof is **bound to the sender** — it cannot be reused by a different address.

---

## Security Considerations

### Current Security Guarantees (Development)

| Property                       | Status         | Notes                                                |
| ------------------------------ | -------------- | ---------------------------------------------------- |
| Address binding                | ✅ Implemented | `evalPoint` is bound to `keccak256(sender)`          |
| Anti-replay (stale commitment) | ✅ Implemented | Monotonic nonce on `WhitelistVerifier`               |
| Unauthorized commitment update | ✅ Implemented | Only `proverEOA` may call `updateCommitment()`       |
| Unauthorized trigger           | ✅ Implemented | Only Reactive callback proxy may call `onCallback()` |
| Cryptographic membership proof | ⚠️ Partial     | Pairing check not yet implemented                    |
| SRS security                   | ⚠️ Weak        | `τ = 7` in development — discrete log is known       |

### Production Security Gaps

1. **Pairing Check Missing**: The BLS12-381 pairing verification that ties `quotientCommitments` to `commitment` is currently a `TODO`. Without it, a user who knows their `evalPoint` could provide fabricated quotient commitments. **Do not use in production without this check.**

2. **Weak SRS**: The development SRS uses `τ = 7`. Anyone can compute `G1 * 7^i` and forge commitments. Replace with a real ceremony.

3. **Single Prover EOA**: The current design trusts a single EOA to submit commitments. Consider using a time-locked multi-sig or SNARK-based prover verification for higher security.

4. **Hook Address Mining**: The hook address must satisfy Uniswap v4's hook flag encoding. Using a random deployment creates a hook with incorrect permissions. Always use CREATE2 with a mined salt in production.

---

## Production Checklist

- [ ] **Replace SRS**: Load `τ` powers from the [Ethereum KZG ceremony](https://ceremony.ethereum.org/) `.ptau` file instead of the development `τ = 7`.
- [ ] **Implement Pairing Check**: Add the EIP-2537 `BLS12_PAIRING` precompile call (`0x0f`) in `WhitelistVerifier.verify()` to fully validate `quotientCommitments` against `commitment`.
- [ ] **Mine Hook Address**: Use a CREATE2 factory to deploy `KZGWhitelistHook` at an address with the `BEFORE_SWAP_FLAG` (`0x0080`) bit set.
- [ ] **Audit Smart Contracts**: Commission a formal security audit before mainnet deployment.
- [ ] **Multi-sig for Admin**: Use a multi-sig (e.g., Safe) for `WhitelistRegistry` and `WhitelistVerifier` owner roles.
- [ ] **Prover Key Security**: Store `PROVER_PRIVATE_KEY` in a hardware security module (HSM) or managed KMS.
- [ ] **Prover Redundancy**: Run multiple prover instances with consensus to avoid a single point of failure.
- [ ] **Proof Expiry**: Consider adding a block-height-based proof expiry mechanism to prevent indefinite reuse of a valid proof.
- [ ] **Gas Optimization**: The `encode_hookdata` ABI encoding (~3KB) adds significant calldata cost. Consider EIP-4844 blobs or Merkle-based compression for cost reduction.
- [ ] **Formal Verification**: Formally verify the `_verifyEvalPoint` and related cryptographic logic using tools like Certora or Halmos.

---

## Troubleshooting

### `WARNING: Hook address does not have BEFORE_SWAP_FLAG!`

The deployed hook address doesn't have the required flag bits. Use a CREATE2 factory to mine a valid address:

```bash
# Mine an address with bit flags matching BEFORE_SWAP_FLAG
cast create2 --starts-with 0x0080 --init-code-hash <keccak of creation bytecode>
```

### Prover shows `Chain submission: disabled`

`PROVER_PRIVATE_KEY` or `VERIFIER_ADDRESS` is not set. Check your `.env` file.

### `StaleNonce()` revert on `updateCommitment`

The prover attempted to submit a nonce ≤ the last accepted nonce. This can happen if the prover restarts and re-processes events. The prover persists `last_nonce` in SQLite — check the database for the current nonce and ensure the prover resumes from the correct block.

### `NotWhitelisted` error on swap

- Verify the address is added to `WhitelistRegistry` on-chain.
- Wait for the prover to poll (up to 7 seconds) and update the commitment.
- Fetch a fresh proof from the prover API: `GET /proof/:address`.
- Ensure the `hookData` is passed correctly in the swap transaction.

### Proof API returns 404 but address is in registry

The prover's local SQLite database may be out of sync. Check the prover logs for errors in the listener loop. You can force a rescan by deleting `prover.db` and restarting (the prover will replay from block 0).

### Rust compilation fails: `blst` not found

Ensure you have a C compiler installed:

```bash
# Ubuntu/Debian
sudo apt install build-essential

# macOS
xcode-select --install
```

---

### Development Workflow

```bash
# Solidity
forge build && forge test -vvv && forge fmt

# Rust
cd kzg-prover && cargo build && cargo test && cargo fmt && cargo clippy
```

---

## License

This project is licensed under the **MIT License**. See [LICENSE](LICENSE) for details.

---

<div align="center">

Built with ❤️ by Wilfred using [Uniswap v4](https://github.com/uniswap/v4-core) · [Foundry](https://getfoundry.sh) · [Reactive Network](https://reactive.network) · [blst](https://github.com/supranational/blst)

</div># Arc-Hook

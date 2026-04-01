// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IWhitelistVerifier} from "./interfaces/IWhitelistVerifier.sol";

/**
 * @title WhitelistVerifier
 * @notice Stores the KZG commitment and verifies membership proofs for the
 *         KZGWhitelistHook. Swappers must prove they are in the whitelist by
 *         providing a valid multilinear KZG opening proof.
 *
 * @dev Proof format (hookData):
 *      abi.encode(uint256 claimedValue, uint256[20] evalPoint, bytes[20] quotientCommitments)
 *
 *      - claimedValue:         must equal 1 (address is whitelisted)
 *      - evalPoint[i]:         bit i of keccak256(abi.encodePacked(sender)), 0 or 1
 *      - quotientCommitments:  n=20 compressed G1 points (48 bytes each), one per
 *                              dimension of the multilinear proof
 *
 * @dev Pairing verification (PRODUCTION TODO):
 *      For each dimension i (0..n-1), the verifier must check:
 *
 *        e(Q_i, [τ]₂ - [z_i]₂) = e(C_{i-1} - C_{i}, [1]₂)
 *
 *      where:
 *        Q_i   = quotientCommitments[i]  (quotient commitment for dimension i)
 *        z_i   = evalPoint[i]            (the i-th coordinate of sender's point)
 *        C_0   = `commitment`            (current stored commitment)
 *        C_i   = running commitment after folding i dimensions
 *        [τ]₂  = G2 generator scaled by τ (from trusted setup)
 *        [1]₂  = G2 generator
 *
 *      This requires the EIP-2537 BLS12-381 precompile (0x0f) for pairing.
 *      Deploy to a network that supports EIP-2537 and implement the check below.
 */
contract WhitelistVerifier is Ownable, IWhitelistVerifier {
    event CommitmentUpdated(bytes commitment, uint64 nonce);

    /// @notice The latest KZG commitment to the whitelist polynomial.
    bytes public commitment;

    /// @notice Monotonically increasing nonce — prevents replay of stale commitments.
    uint64 public lastNonce;

    /// @notice The prover EOA authorised to call updateCommitment().
    address public proverEOA;

    error UnauthorizedProver();
    error StaleNonce();
    error InvalidProof();

    constructor(address _proverEOA) Ownable(msg.sender) {
        proverEOA = _proverEOA;
    }

    function setProverEOA(address _proverEOA) external onlyOwner {
        proverEOA = _proverEOA;
    }

    /**
     * @notice Update the stored KZG commitment.
     * @dev Called by the off-chain prover after every whitelist change.
     *      Only the registered proverEOA may call this.
     * @param _commitment   48-byte compressed G1 point (BLS12-381).
     * @param _nonce        Must be strictly greater than lastNonce.
     */
    function updateCommitment(bytes calldata _commitment, uint64 _nonce) external {
        if (msg.sender != proverEOA) revert UnauthorizedProver();
        if (_nonce <= lastNonce) revert StaleNonce();

        commitment = _commitment;
        lastNonce = _nonce;

        emit CommitmentUpdated(_commitment, _nonce);
    }

    /**
     * @notice Verify a KZG membership proof for `sender`.
     *
     * @param sender    The address attempting to swap.
     * @param hookData  ABI-encoded proof: see contract-level dev comment for format.
     * @return True if the evaluation point matches the sender AND claimedValue == 1.
     *
     * @dev Security note:
     *      In this development version the cryptographic pairing check is OMITTED.
     *      The evalPoint check (which IS implemented) ensures the proof is bound to
     *      the sender address — a different address cannot reuse the same evalPoint.
     *      However, without the pairing check, a malicious user could fabricate
     *      quotientCommitments. See the production TODO above for the full check.
     */
    function verify(address sender, bytes calldata hookData) external pure returns (bool) {
        // Minimum length: 32 (claimedValue) + 20*32 (evalPoint) + 32 (bytes[20] offset)
        if (hookData.length < 32 + 20 * 32 + 32) return false;

        // quotientCommitments are decoded here but validated via pairing (production TODO)
        (uint256 claimedValue, uint256[20] memory evalPoint, bytes[20] memory quotientCommitments) =
            abi.decode(hookData, (uint256, uint256[20], bytes[20]));
        // Suppress unused variable warning until pairing check is implemented
        quotientCommitments;

        // 1. The polynomial must evaluate to 1 at the sender's point.
        if (claimedValue != 1) return false;

        // 2. The evaluation point must match the sender's address.
        //    This binds the proof to this specific sender and cannot be replayed.
        if (!_verifyEvalPoint(sender, evalPoint)) return false;

        // 3. (PRODUCTION) Pairing check — omitted in dev; see contract-level doc.
        //    Implement using EIP-2537 precompile 0x0f once deploying to a supported network.

        return true;
    }

    /**
     * @notice Verify that evalPoint[i] == bit i of keccak256(abi.encodePacked(addr)).
     * @dev    Matches the Rust `address_to_hypercube_bits` function in encoding.rs.
     *         `uint256(hash) >> i` extracts bit i counting from the LSB.
     */
    function _verifyEvalPoint(address addr, uint256[20] memory evalPoint) internal pure returns (bool) {
        bytes32 hash = keccak256(abi.encodePacked(addr));
        for (uint256 i = 0; i < 20; i++) {
            uint256 bit = (uint256(hash) >> i) & 1;
            if (evalPoint[i] != bit) return false;
        }
        return true;
    }
}

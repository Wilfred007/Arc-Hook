// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console2} from "forge-std/Test.sol";
import {WhitelistRegistry} from "../src/WhitelistRegistry.sol";
import {WhitelistVerifier} from "../src/WhitelistVerifier.sol";
import {ProverTrigger} from "../src/ProverTrigger.sol";
import {KZGWhitelistHook} from "../src/KZGWhitelistHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

contract KZGWhitelistTest is Test {
    WhitelistRegistry registry;
    WhitelistVerifier verifier;
    ProverTrigger trigger;
    KZGWhitelistHook hook;
    PoolManager manager;

    address alice = address(0x111);
    address bob = address(0x222);
    address proverEOA = address(0x333);
    address rscProxy = address(0x444);

    function setUp() public {
        manager = new PoolManager(address(0));
        registry = new WhitelistRegistry();
        verifier = new WhitelistVerifier(proverEOA);
        trigger = new ProverTrigger(rscProxy);

        // Deploy hook with correct flags (BeforeSwap)
        // In Foundry, we can just use the address or deploy properly.
        hook = new KZGWhitelistHook(manager, verifier);
    }

    function test_whitelist_flow() public {
        // 1. Alice is not whitelisted
        vm.prank(alice);
        bytes memory emptyProof = ""; // Minimal proof that will fail length check
        // We expect verify to return false
        assertFalse(verifier.verify(alice, emptyProof));

        // 2. Add Alice to registry
        registry.addAddress(alice);

        // 3. Mock Reactive RSC callback to trigger
        vm.prank(rscProxy);
        trigger.onCallback(alice, true, 1);

        // 4. Prover updates verifier
        bytes memory mockCommitment = hex"1234";
        vm.prank(proverEOA);
        verifier.updateCommitment(mockCommitment, 1);

        // 5. Alice generates proof and swaps
        // We'll mock the proof verification for now by giving it correct length and matching bits
        bytes32 hash = keccak256(abi.encodePacked(alice));
        uint256[20] memory evalPoint;
        for (uint256 i = 0; i < 20; i++) {
            evalPoint[i] = (uint256(hash) >> i) & 1;
        }
        bytes[20] memory quotientCommitments;
        for (uint i = 0; i < 20; i++) quotientCommitments[i] = new bytes(48);

        bytes memory proof = abi.encode(
            uint256(1),
            evalPoint,
            quotientCommitments
        );

        assertTrue(verifier.verify(alice, proof));

        // 6. Test hook revert for Bob
        vm.expectRevert(
            abi.encodeWithSelector(
                KZGWhitelistHook.NotWhitelisted.selector,
                bob
            )
        );
        vm.prank(address(manager)); // Mock call from manager
        hook.beforeSwap(
            bob,
            PoolKey(
                Currency.wrap(address(0)),
                Currency.wrap(address(0)),
                0,
                0,
                IHooks(address(0))
            ),
            SwapParams(true, 0, 0),
            proof
        );

        // 7. Test hook success for Alice
        vm.prank(address(manager));
        (bytes4 selector, , ) = hook.beforeSwap(
            alice,
            PoolKey(
                Currency.wrap(address(0)),
                Currency.wrap(address(0)),
                0,
                0,
                IHooks(address(0))
            ),
            SwapParams(true, 0, 0),
            proof
        );
        assertEq(selector, IHooks.beforeSwap.selector);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {WhitelistRegistry} from "../src/WhitelistRegistry.sol";
import {WhitelistVerifier} from "../src/WhitelistVerifier.sol";
import {ProverTrigger} from "../src/ProverTrigger.sol";
import {KZGWhitelistHook} from "../src/KZGWhitelistHook.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proverEOA = vm.envAddress("PROVER_ADDRESS");
        address rscProxy = vm.envAddress("RSC_PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy PoolManager (Mock or real depending on network)
        PoolManager manager = new PoolManager(address(0));
        console2.log("PoolManager deployed at:", address(manager));

        // 2. Deploy Registry
        WhitelistRegistry registry = new WhitelistRegistry();
        console2.log("WhitelistRegistry deployed at:", address(registry));

        // 3. Deploy Verifier
        WhitelistVerifier verifier = new WhitelistVerifier(proverEOA);
        console2.log("WhitelistVerifier deployed at:", address(verifier));

        // 4. Deploy Trigger
        ProverTrigger trigger = new ProverTrigger(rscProxy);
        console2.log("ProverTrigger deployed at:", address(trigger));

        // 5. Deploy Hook
        KZGWhitelistHook hook = new KZGWhitelistHook(manager, verifier);
        console2.log("KZGWhitelistHook deployed at:", address(hook));

        vm.stopBroadcast();
    }
}

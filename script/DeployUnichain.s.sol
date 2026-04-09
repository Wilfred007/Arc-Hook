// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {WhitelistRegistry} from "../src/WhitelistRegistry.sol";
import {WhitelistVerifier} from "../src/WhitelistVerifier.sol";
import {ProverTrigger} from "../src/ProverTrigger.sol";
import {KZGWhitelistHook} from "../src/KZGWhitelistHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

contract DeployUnichain is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("UNICHAIN_PRIVATE_KEY");
        address proverEOA = vm.envAddress("PROVER_ADDRESS");
        address rscProxy = vm.envAddress("REACTIVE_SYSTEM_CONTRACT"); // Lasna/Mainnet proxy
        address poolManager = vm.envAddress("POOL_MANAGER");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Registry
        WhitelistRegistry registry = new WhitelistRegistry();
        console2.log("WhitelistRegistry deployed at:", address(registry));

        // 2. Deploy Verifier
        WhitelistVerifier verifier = new WhitelistVerifier(proverEOA);
        console2.log("WhitelistVerifier deployed at:", address(verifier));

        // 3. Deploy Trigger
        ProverTrigger trigger = new ProverTrigger(rscProxy);
        console2.log("ProverTrigger deployed at:", address(trigger));

        // 4. Deploy Hook with mined salt (salt = 14596)
        // This ensures the hook address has BEFORE_SWAP_FLAG set. (predicted: 0xf32D9a866717c6311F3c7a159373589e96e58080)
        bytes32 salt = bytes32(uint256(14596));
        KZGWhitelistHook hook = new KZGWhitelistHook{salt: salt}(IPoolManager(poolManager), verifier);
        console2.log("KZGWhitelistHook deployed at:", address(hook));

        uint160 hookAddress = uint160(address(hook));
        if ((hookAddress & uint160(Hooks.BEFORE_SWAP_FLAG)) == 0) {
            console2.log("WARNING: Hook address still does not have BEFORE_SWAP_FLAG!");
            console2.log("Mining might have changed if manager or verifier changed.");
        } else {
            console2.log("SUCCESS: Hook address has BEFORE_SWAP_FLAG.");
        }

        vm.stopBroadcast();
    }
}

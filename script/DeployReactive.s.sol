// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {KZGWhitelistRSC} from "../src/reactive/KZGWhitelistRSC.sol";

contract DeployReactive is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        uint256 originChainId = vm.envUint("ORIGIN_CHAIN_ID"); // e.g., 1301 for Unichain Sepolia
        address registryAddr = vm.envAddress("REGISTRY_ADDRESS");

        uint256 destChainId = vm.envUint("DEST_CHAIN_ID"); // e.g., 1301 for Unichain Sepolia
        address triggerAddr = vm.envAddress("TRIGGER_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy the Reactive Smart Contract
        KZGWhitelistRSC rsc = new KZGWhitelistRSC(
            originChainId,
            registryAddr,
            destChainId,
            triggerAddr
        );

        console2.log("KZGWhitelistRSC deployed at:", address(rsc));

        vm.stopBroadcast();
    }
}

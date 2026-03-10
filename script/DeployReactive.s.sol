// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {
    KZGWhitelistRSC,
    ISystemContract
} from "../src/reactive/KZGWhitelistRSC.sol";

contract DeployReactive is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("REACTIVE_PRIVATE_KEY");

        uint256 originChainId = vm.envUint("ORIGIN_CHAIN_ID");
        address registryAddr = vm.envAddress("REGISTRY_ADDRESS");

        uint256 destChainId = vm.envUint("DEST_CHAIN_ID");
        address triggerAddr = vm.envAddress("TRIGGER_ADDRESS");

        address systemContractAddr = vm.envAddress("REACTIVE_SYSTEM_CONTRACT");

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

    uint256 constant REACTIVE_LOG_ANY =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
}

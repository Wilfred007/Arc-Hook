// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {KZGWhitelistHook} from "../src/KZGWhitelistHook.sol";
import {WhitelistVerifier} from "../src/WhitelistVerifier.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

contract DeployHook is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("UNICHAIN_PRIVATE_KEY");
        address poolManager = 0x9e512795Be621572Ef073bc4d395554F71334D8a;
        // Use the most recent Verifier with the fixed bit-order
        address verifier    = 0xaC456b9444251607B9d1a2E356b737f67B8D6840;

        vm.startBroadcast(deployerPrivateKey);

        bytes32 salt = bytes32(uint256(3554)); // mined for BEFORE_SWAP_FLAG
        KZGWhitelistHook hook = new KZGWhitelistHook{salt: salt}(
            IPoolManager(poolManager),
            WhitelistVerifier(verifier)
        );
        console2.log("KZGWhitelistHook deployed at:", address(hook));

        uint160 hookAddr = uint160(address(hook));
        if ((hookAddr & uint160(Hooks.BEFORE_SWAP_FLAG)) != 0) {
            console2.log("SUCCESS: BEFORE_SWAP_FLAG is set.");
        } else {
            console2.log("ERROR: BEFORE_SWAP_FLAG NOT set. Wrong salt?");
        }

        vm.stopBroadcast();
    }
}

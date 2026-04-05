// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {KZGWhitelistHook} from "../src/KZGWhitelistHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IWhitelistVerifier} from "../src/interfaces/IWhitelistVerifier.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

contract HookMiner is Script {
    function run() external {
        address manager = vm.envAddress("POOL_MANAGER");
        address verifier = vm.envAddress("VERIFIER_ADDRESS");

        // The bytecode and its hash are no longer needed if initCodeHash is hardcoded.
        // bytes memory bytecode = abi.encodePacked(
        //     type(KZGWhitelistHook).creationCode,
        //     abi.encode(manager, verifier)
        // );
        // console2.log("Bytecode Hash:", vm.toString(keccak256(bytecode)));
        
        address factory = 0xDca631229e1955668f05BB8d1c4eEd9acB4D8668;
        
        console2.log("Mining salt for BEFORE_SWAP_FLAG (1 << 7) via Factory...");
        // Override initCodeHash with the one logged by DeployHook
        bytes32 initCodeHash = 0x56574495b645eac71988fce35b69b55b3257afd075c4284085b532399488903d;

        for (uint256 i = 0; i < 10000; i++) {
            bytes32 salt = bytes32(i);
            address hookAddress = address(uint160(uint256(keccak256(abi.encodePacked(
                bytes1(0xff),
                factory,
                salt,
                initCodeHash
            )))));
            
            if ((uint160(hookAddress) & Hooks.ALL_HOOK_MASK) == Hooks.BEFORE_SWAP_FLAG) {
                console2.log("Found salt:", i);
                console2.log("Hook Address:", hookAddress);
                return;
            }
        }
        
        console2.log("No exact salt found in 10,000 iterations. Searching up to 100,000...");
        for (uint256 i = 10000; i < 100000; i++) {
            bytes32 salt = bytes32(i);
            address hookAddress = address(uint160(uint256(keccak256(abi.encodePacked(
                bytes1(0xff),
                factory,
                salt,
                initCodeHash
            )))));
            if ((uint160(hookAddress) & Hooks.ALL_HOOK_MASK) == Hooks.BEFORE_SWAP_FLAG) {
                console2.log("Found salt:", i);
                console2.log("Hook Address:", hookAddress);
                return;
            }
        }
        
        console2.log("No salt found in 10,000 iterations. Try a larger range.");
    }
}

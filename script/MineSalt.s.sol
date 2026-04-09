// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {KZGWhitelistHook} from "../src/KZGWhitelistHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {WhitelistVerifier} from "../src/WhitelistVerifier.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

contract MineSalt is Script {
    function run() external view {
        address poolManager = 0x9e512795Be621572Ef073bc4d395554F71334D8a;
        address verifier    = 0xE54B61b3419E79f9b9e52776C61a15A9e61600D5;
        address deployer    = 0x052faB7c34011dA32d117d8354bdEC6b0Ca28d6e;
        address factory     = 0x4e59b44847b379578588920cA78FbF26c0B4956C; // deterministic CREATE2 factory

        bytes memory creationCode = abi.encodePacked(
            type(KZGWhitelistHook).creationCode,
            abi.encode(poolManager, verifier)
        );
        bytes32 codeHash = keccak256(creationCode);

        uint160 hookFlagsMask = 0x3FFF; // 14 bits for flags
        uint160 expectedFlags = uint160(Hooks.BEFORE_SWAP_FLAG); // only beforeSwap is true

        for (uint256 salt = 0; salt < 100000; salt++) { // Increased search range
            bytes32 saltBytes = bytes32(salt);
            address predicted = address(uint160(uint256(keccak256(abi.encodePacked(
                bytes1(0xff),
                factory,
                saltBytes,
                codeHash
            )))));
            
            if ((uint160(predicted) & hookFlagsMask) == expectedFlags) {
                console2.log("Found valid salt:", salt);
                console2.log("Hook will deploy at:", predicted);
                console2.log("Flags check passed: Exactly beforeSwap bit set");
                return;
            }
        }
        console2.log("No valid salt found in range 0-99999");
    }
}

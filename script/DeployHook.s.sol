// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {KZGWhitelistHook} from "../src/KZGWhitelistHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IWhitelistVerifier} from "../src/interfaces/IWhitelistVerifier.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {Create2Factory} from "../src/Create2Factory.sol";

contract DeployHook is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("UNICHAIN_PRIVATE_KEY");
        address poolManager = vm.envAddress("POOL_MANAGER");
        address verifier = vm.envAddress("VERIFIER_ADDRESS");
        uint256 saltInt = vm.envUint("HOOK_SALT");
        
        bytes memory bytecode = abi.encodePacked(
            type(KZGWhitelistHook).creationCode,
            abi.encode(poolManager, verifier)
        );
        console2.log("Bytecode Hash:", vm.toString(keccak256(bytecode)));

        address factory = 0xDca631229e1955668f05BB8d1c4eEd9acB4D8668;
        bytes32 salt = bytes32(saltInt);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy via Factory
        address hookAddr = Create2Factory(factory).deploy(bytecode, salt);
        KZGWhitelistHook hook = KZGWhitelistHook(hookAddr);
        console2.log("KZGWhitelistHook deployed at:", address(hook));

        uint160 hookAddress = uint160(address(hook));
        if ((hookAddress & uint160(Hooks.BEFORE_SWAP_FLAG)) == 0) {
            console2.log("ERROR: Hook address does not have BEFORE_SWAP_FLAG!");
        } else {
            console2.log("SUCCESS: Hook address has BEFORE_SWAP_FLAG.");
        }

        vm.stopBroadcast();
    }
}

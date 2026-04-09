// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {Create2Factory} from "../src/Create2Factory.sol";

contract DeployRouter is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("UNICHAIN_PRIVATE_KEY");
        address poolManager = 0x9e512795Be621572Ef073bc4d395554F71334D8a;
        address factoryAddr = 0xDca631229e1955668f05BB8d1c4eEd9acB4D8668;

        vm.startBroadcast(deployerPrivateKey);
        
        bytes memory swapBytecode = abi.encodePacked(
            type(PoolSwapTest).creationCode,
            abi.encode(poolManager)
        );
        address swapAddr = Create2Factory(factoryAddr).deploy(swapBytecode, bytes32(uint256(2001)));
        console2.log("Swap Router deployed at:", swapAddr);

        vm.stopBroadcast();
    }
}

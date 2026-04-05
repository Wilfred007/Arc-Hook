// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";

contract DeployPoolManager is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("UNICHAIN_PRIVATE_KEY");
        
        address proverEOA = vm.envAddress("PROVER_ADDRESS");
        
        vm.startBroadcast(deployerPrivateKey);

        PoolManager manager = new PoolManager(proverEOA);
        console2.log("PoolManager deployed at:", address(manager));

        vm.stopBroadcast();
    }
}

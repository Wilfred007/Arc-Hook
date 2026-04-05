// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {MockToken} from "./InitializePool.s.sol";
import {Create2Factory} from "../src/Create2Factory.sol";

contract DeployTokens is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("UNICHAIN_PRIVATE_KEY");
        address factoryAddr = 0xDca631229e1955668f05BB8d1c4eEd9acB4D8668;
        vm.startBroadcast(deployerPrivateKey);

        address deployer = vm.addr(deployerPrivateKey);
        bytes memory token0Bytecode = abi.encodePacked(type(MockToken).creationCode, abi.encode("Token Red", "REDA", deployer));
        bytes memory token1Bytecode = abi.encodePacked(type(MockToken).creationCode, abi.encode("Token Blue", "BLUE", deployer));

        address token0 = Create2Factory(factoryAddr).deploy(token0Bytecode, bytes32(uint256(11)));
        address token1 = Create2Factory(factoryAddr).deploy(token1Bytecode, bytes32(uint256(12)));

        console2.log("Token0 deployed at:", token0);
        console2.log("Token1 deployed at:", token1);

        vm.stopBroadcast();
    }
}

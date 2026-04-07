// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol, address beneficiary) ERC20(name, symbol) {
        _mint(beneficiary, 1000000 * 10**18);
    }
}

contract InitializePool is Script {
    using CurrencyLibrary for Currency;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("UNICHAIN_PRIVATE_KEY");
        address poolManager = vm.envAddress("POOL_MANAGER");
        address hook = vm.envAddress("HOOK_ADDRESS");

        console2.log("Using PoolManager:", poolManager);
        console2.log("Using Hook:", hook);

        vm.startBroadcast(deployerPrivateKey);

        // 1. Use Existing Tokens
        address token0Addr = vm.envAddress("TOKEN0");
        address token1Addr = vm.envAddress("TOKEN1");
        
        console2.log("Token0:", token0Addr);
        console2.log("Token1:", token1Addr);

        // Sort currencies
        Currency currency0 = token0Addr < token1Addr ? Currency.wrap(token0Addr) : Currency.wrap(token1Addr);
        Currency currency1 = token0Addr < token1Addr ? Currency.wrap(token1Addr) : Currency.wrap(token0Addr);

        PoolKey memory key = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });

        // 2. Initialize Pool
        // sqrtPriceX96 for 1:1 price is 2**96
        uint160 sqrtPriceX96 = 79228162514264337593543950336; 
        IPoolManager(poolManager).initialize(key, sqrtPriceX96);
        console2.log("Pool initialized!");

        vm.stopBroadcast();
    }
}

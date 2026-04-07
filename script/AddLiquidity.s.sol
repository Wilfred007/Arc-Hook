// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {MockToken} from "./InitializePool.s.sol";
import {ModifyLiquidityParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";

import {PoolModifyLiquidityTest} from "@uniswap/v4-core/src/test/PoolModifyLiquidityTest.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {Create2Factory} from "../src/Create2Factory.sol";

contract AddLiquidity is Script {
    using CurrencyLibrary for Currency;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("UNICHAIN_PRIVATE_KEY");
        address poolManager = vm.envAddress("POOL_MANAGER");
        address hook = vm.envAddress("HOOK_ADDRESS");
        address token0Addr = vm.envAddress("TOKEN0");
        address token1Addr = vm.envAddress("TOKEN1");

        address factoryAddr = 0xDca631229e1955668f05BB8d1c4eEd9acB4D8668;
        
        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Helper via Factory
        bytes memory routerBytecode = abi.encodePacked(
            type(PoolModifyLiquidityTest).creationCode,
            abi.encode(poolManager)
        );
        address routerAddr = Create2Factory(factoryAddr).deploy(routerBytecode, bytes32(uint256(1001)));
        PoolModifyLiquidityTest lpRouter = PoolModifyLiquidityTest(routerAddr);
        console2.log("LP Router deployed at:", address(lpRouter));

        MockToken token0 = MockToken(token0Addr);
        MockToken token1 = MockToken(token1Addr);

        // Sort currencies
        address currency0 = token0Addr < token1Addr ? token0Addr : token1Addr;
        address currency1 = token0Addr < token1Addr ? token1Addr : token0Addr;

        // 2. Approve Helper
        token0.approve(address(lpRouter), type(uint256).max);
        token1.approve(address(lpRouter), type(uint256).max);

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(currency0),
            currency1: Currency.wrap(currency1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });

        // 3. Add liquidity
        // Tick range: -60 to 60 (near current price)
        lpRouter.modifyLiquidity(
            key,
            ModifyLiquidityParams({
                tickLower: -60,
                tickUpper: 60,
                liquidityDelta: 100 * 10**18, // 100 units
                salt: 0
            }),
            "" // No hook data needed for adding liquidity in this hook
        );
        
        console2.log("Liquidity added successfully!");
        
        vm.stopBroadcast();
    }
}

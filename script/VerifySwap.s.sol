// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {Create2Factory} from "../src/Create2Factory.sol";
import {MockToken} from "./InitializePool.s.sol";

contract VerifySwap is Script {
    using CurrencyLibrary for Currency;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("UNICHAIN_PRIVATE_KEY");
        address poolManager = 0x9e512795Be621572Ef073bc4d395554F71334D8a;
        address hook = 0xb9877b41424B21126134e0f0C66E43Cfa24d0080;
        address token0Addr = 0xcd96C9122C82905C2EB956e79703E12cCf409194;
        address token1Addr = 0xBA567f3150aBde130b0De648ca076eC19796994C;
        address factoryAddr = 0xDca631229e1955668f05BB8d1c4eEd9acB4D8668;

        vm.startBroadcast(deployerPrivateKey);

        // 1. Deploy Swap Router via Factory
        bytes memory swapBytecode = abi.encodePacked(
            type(PoolSwapTest).creationCode,
            abi.encode(poolManager)
        );
        address swapAddr = Create2Factory(factoryAddr).deploy(swapBytecode, bytes32(uint256(2001)));
        PoolSwapTest swapRouter = PoolSwapTest(swapAddr);
        console2.log("Swap Router deployed at:", address(swapRouter));

        // 2. Approve Swap Router
        MockToken(token0Addr).approve(address(swapRouter), type(uint256).max);
        MockToken(token1Addr).approve(address(swapRouter), type(uint256).max);
        vm.stopBroadcast();

        vm.startBroadcast(deployerPrivateKey);

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(token0Addr < token1Addr ? token0Addr : token1Addr),
            currency1: Currency.wrap(token0Addr < token1Addr ? token1Addr : token0Addr),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(hook)
        });

        // 3. Attempt Swap WITHOUT hook data (Expect Revert)
        console2.log("Attempting swap WITHOUT hook data...");
        try swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: true,
                amountSpecified: -1e15, // 0.001 units
                sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1
            }),
            PoolSwapTest.TestSettings({
                takeClaims: false,
                settleUsingBurn: false
            }),
            ""
        ) {
            console2.log("ERROR: Swap SHOULD have reverted!");
        } catch (bytes memory reason) {
            console2.log("SUCCESS: Swap reverted as expected.");
            // console2.logBytes(reason);
        }

        vm.stopBroadcast();
    }
}

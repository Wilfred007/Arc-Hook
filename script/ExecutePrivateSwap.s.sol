// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {PoolSwapTest} from "@uniswap/v4-core/src/test/PoolSwapTest.sol";
import {Create2Factory} from "../src/Create2Factory.sol";

interface IERC20Minimal {
    function approve(address spender, uint256 amount) external returns (bool);
}

contract ExecutePrivateSwap is Script {
    using CurrencyLibrary for Currency;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("UNICHAIN_PRIVATE_KEY");
        address poolManager = vm.envAddress("POOL_MANAGER");
        address hook = vm.envAddress("HOOK_ADDRESS");
        address token0Addr = vm.envAddress("TOKEN0");
        address token1Addr = vm.envAddress("TOKEN1");
        
        // Use the broadcaster's own address (which is already whitelisted)
        address sender = vm.addr(deployerPrivateKey);

        // Use the Router address that we have already whitelisted and the Prover knows
        address swapAddr = 0xffE995C899CaBaC944E0ef3EB27b167F03B10eae;
        PoolSwapTest swapRouter = PoolSwapTest(swapAddr);
        console2.log("Using Swap Router at:", address(swapRouter));

        // 2. Fetch the real proof for the ROUTER from the Rust API via FFI helper script
        // Note: In Uniswap v4, the 'sender' seen by the hook is the caller of manager.swap (the Router).
        string[] memory inputs = new string[](3);
        inputs[0] = "./script/get_proof.sh";
        inputs[1] = vm.toString(address(swapRouter));
        inputs[2] = "proof.txt";
        
        vm.ffi(inputs);
        
        // Read proof from file (must be in project root for default Foundry permissions)
        string memory proofStr = vm.readFile("proof.txt");
        
        if (bytes(proofStr).length < 100) {
            console2.log("Error: Failed to fetch valid proof string from Prover API.");
            vm.stopBroadcast();
            return;
        }

        bytes memory proof = vm.parseBytes(proofStr);
        console2.log("Successfully fetched and decoded KZG proof (length):", proof.length);

        vm.startBroadcast(deployerPrivateKey);

        // 3. Approve Swap Router
        IERC20Minimal(token0Addr).approve(address(swapRouter), type(uint256).max);
        IERC20Minimal(token1Addr).approve(address(swapRouter), type(uint256).max);

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

        // 4. Execute Swap WITH Proof
        console2.log("Attempting swap WITH valid proof...");
        
        swapRouter.swap(
            key,
            SwapParams({
                zeroForOne: true, 
                amountSpecified: -1000000000000000, // -0.001 units
                sqrtPriceLimitX96: 4295128740
            }),
            PoolSwapTest.TestSettings({ takeClaims: false, settleUsingBurn: false }),
            proof
        );
        
        console2.log("SUCCESS: Private Swap executed successfully!");

        vm.stopBroadcast();
    }
}

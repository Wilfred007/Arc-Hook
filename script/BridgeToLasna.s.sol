// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";

/**
 * @title BridgeToLasna
 * @notice Sends ETH to the Lasna Faucet on Sepholia or Base Sepholia to get lREACT.
 *         Follows the 1 ETH -> 100 lREACT exchange rate.
 */
contract BridgeToLasna is Script {
    // Lasna Faucet on Ethereum Sepolia
    address constant ETHEREUM_SEPOLIA_FAUCET = 0x9b9BB25f1A81078C544C829c5EB7822d747Cf434;
    
    // Lasna Faucet on Base Sepolia
    address constant BASE_SEPOLIA_FAUCET = 0x2afaFD298b23b62760711756088F75B7409f5967;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("REACTIVE_PRIVATE_KEY");
        address faucetAddr = vm.envAddress("FAUCET_ADDRESS");
        uint256 amount = vm.envUint("BRIDGE_AMOUNT"); // In wei

        if (faucetAddr != ETHEREUM_SEPOLIA_FAUCET && faucetAddr != BASE_SEPOLIA_FAUCET) {
            console2.log("WARNING: Provided faucet address does not match known Lasna faucets.");
        }

        if (amount > 5 ether) {
            console2.log("ERROR: Maximum 5 ETH per transaction allowed.");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);

        // Sending ETH to the faucet triggers the lREACT minting on Lasna
        (bool success, ) = faucetAddr.call{value: amount}("");
        require(success, "Transfer failed");

        console2.log("Successfully sent", amount, "wei to faucet:", faucetAddr);
        console2.log("You should receive lREACT on Lasna Testnet shortly.");

        vm.stopBroadcast();
    }
}

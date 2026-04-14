// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {WhitelistVerifier} from "../src/WhitelistVerifier.sol";
import {KZGWhitelistHook} from "../src/KZGWhitelistHook.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

contract DeployHashKeyHook is Script {
    // Foundry routes CREATE2 deployments through this canonical deployer.
    address internal constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run(address poolManager, address proverEOA) external {
        vm.startBroadcast();

        WhitelistVerifier verifier = new WhitelistVerifier(proverEOA);
        console2.log("WhitelistVerifier deployed at:", address(verifier));

        bytes32 initCodeHash = keccak256(
            abi.encodePacked(type(KZGWhitelistHook).creationCode, abi.encode(IPoolManager(poolManager), verifier))
        );

        (bool found, bytes32 salt, address predictedHook) = _mineSalt(CREATE2_DEPLOYER, initCodeHash, 1_000_000);
        require(found, "No valid salt found in search range");

        console2.log("Mined salt:", uint256(salt));
        console2.log("Predicted hook address:", predictedHook);

        KZGWhitelistHook hook = new KZGWhitelistHook{salt: salt}(IPoolManager(poolManager), verifier);
        console2.log("KZGWhitelistHook deployed at:", address(hook));

        uint160 hookAddress = uint160(address(hook));
        require((hookAddress & uint160(Hooks.ALL_HOOK_MASK)) == Hooks.BEFORE_SWAP_FLAG, "Invalid hook flags");
        console2.log("SUCCESS: Hook address has ONLY BEFORE_SWAP_FLAG.");

        vm.stopBroadcast();
    }

    function _mineSalt(address deployer, bytes32 initCodeHash, uint256 maxIterations)
        internal
        pure
        returns (bool found, bytes32 salt, address predicted)
    {
        for (uint256 i = 0; i < maxIterations; i++) {
            bytes32 candidateSalt = bytes32(i);
            address candidate = _computeCreate2(deployer, candidateSalt, initCodeHash);
            if ((uint160(candidate) & uint160(Hooks.ALL_HOOK_MASK)) == Hooks.BEFORE_SWAP_FLAG) {
                return (true, candidateSalt, candidate);
            }
        }
        return (false, bytes32(0), address(0));
    }

    function _computeCreate2(address deployer, bytes32 salt, bytes32 initCodeHash) internal pure returns (address) {
        return address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), deployer, salt, initCodeHash)))));
    }
}

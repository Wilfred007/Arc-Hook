// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IWhitelistVerifier {
    function verify(
        address sender,
        bytes calldata hookData
    ) external view returns (bool);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract WhitelistRegistry is Ownable {
    event WhitelistUpdated(address indexed addr, bool added, uint256 nonce);

    uint256 public nonce;
    mapping(address => bool) public isWhitelisted;

    constructor() Ownable(msg.sender) {}

    function addAddress(address addr) external onlyOwner {
        isWhitelisted[addr] = true;
        emit WhitelistUpdated(addr, true, ++nonce);
    }

    function removeAddress(address addr) external onlyOwner {
        isWhitelisted[addr] = false;
        emit WhitelistUpdated(addr, false, ++nonce);
    }
}

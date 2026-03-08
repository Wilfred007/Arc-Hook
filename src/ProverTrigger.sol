// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ProverTrigger
 * @notice Receives whitelist update callbacks from the Reactive Network
 *         callback proxy and emits events that the off-chain KZG prover watches.
 *
 * @dev The call flow is:
 *      WhitelistRegistry (origin chain)
 *        → KZGWhitelistRSC (Reactive Network)
 *          → ProverTrigger.onCallback()  ← only the callback proxy may call this
 *            → emits TriggerReceived
 *              → off-chain KZG prover sees the event and recomputes the commitment
 */
contract ProverTrigger is Ownable {
    event TriggerReceived(address indexed addr, bool added, uint256 nonce);

    /// @notice The Reactive Network callback proxy that is authorised to call onCallback().
    address public reactiveCallbackProxy;

    error Unauthorized();

    constructor(address _reactiveCallbackProxy) Ownable(msg.sender) {
        reactiveCallbackProxy = _reactiveCallbackProxy;
    }

    /**
     * @notice Update the authorised reactive callback proxy.
     * @dev    Only callable by the contract owner.
     */
    function setReactiveCallbackProxy(address _proxy) external onlyOwner {
        reactiveCallbackProxy = _proxy;
    }

    /**
     * @notice Called by the Reactive Network callback proxy when a whitelist
     *         change is relayed from the origin chain.
     *
     * @param addr    The address that was added or removed.
     * @param added   True if added, false if removed.
     * @param nonce   The monotonic nonce from WhitelistRegistry at the time of the update.
     */
    function onCallback(address addr, bool added, uint256 nonce) external {
        if (msg.sender != reactiveCallbackProxy) revert Unauthorized();
        emit TriggerReceived(addr, added, nonce);
    }
}

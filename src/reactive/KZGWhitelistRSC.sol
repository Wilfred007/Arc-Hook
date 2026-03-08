// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title IReactive
 * @notice Simplified interface for Reactive Network smart contracts.
 */
interface IReactive {
    struct LogEntry {
        uint256 chainId;
        address source;
        uint256[] topics;
        bytes data;
        uint256 blockNumber;
        uint256 logIndex;
        uint256 transactionIndex;
        bytes32 transactionHash;
    }

    event Callback(
        uint256 indexed chainId,
        address indexed target,
        uint256 gasLimit,
        bytes payload
    );

    function react(LogEntry calldata log) external;
}

/**
 * @title KZGWhitelistRSC
 * @notice Reactive Smart Contract that relays WhitelistUpdated events.
 */
contract KZGWhitelistRSC is IReactive {
    uint256 public immutable originChainId;
    address public immutable registryAddress;
    uint256 public immutable destinationChainId;
    address public immutable triggerAddress;

    // event WhitelistUpdated(address indexed addr, bool added, uint256 nonce);
    // Topic 0: keccak256("WhitelistUpdated(address,bool,uint256)")
    bytes32 private constant WHITELIST_UPDATED_TOPIC_0 =
        0x0f2ab3269df45d41960fdf14c84cd22dfb81c269985eecc7ee6b93764639ae45;

    // Wait, let me calculate it properly.
    // keccak256("WhitelistUpdated(address,bool,uint256)")
    // index 0: addr, index 1: added, data: nonce?
    // Wait, in my WhitelistRegistry:
    // event WhitelistUpdated(address indexed addr, bool added, uint256 nonce);
    // Topics:
    // [0] : sig
    // [1] : addr
    // Data:
    // bool added, uint256 nonce (both in data because added is not indexed)

    constructor(
        uint256 _originChainId,
        address _registryAddress,
        uint256 _destinationChainId,
        address _triggerAddress
    ) {
        originChainId = _originChainId;
        registryAddress = _registryAddress;
        destinationChainId = _destinationChainId;
        triggerAddress = _triggerAddress;
    }

    function react(LogEntry calldata log) external override {
        if (log.chainId != originChainId || log.source != registryAddress)
            return;
        if (log.topics.length < 2) return;
        if (bytes32(log.topics[0]) != WHITELIST_UPDATED_TOPIC_0) return;

        address addr = address(uint160(log.topics[1]));
        (bool added, uint256 nonce) = abi.decode(log.data, (bool, uint256));

        // Relay the event to the trigger contract on the destination chain
        emit Callback(
            destinationChainId,
            triggerAddress,
            200000, // gasLimit
            abi.encodeWithSignature(
                "onCallback(address,bool,uint256)",
                addr,
                added,
                nonce
            )
        );
    }
}

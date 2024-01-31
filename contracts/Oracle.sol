// SPDX-License-Identifier: BSL 1.1
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {PreConfCommitmentStore} from "./PreConfirmations.sol";
import {IProviderRegistry} from "./interfaces/IProviderRegistry.sol";
import {IPreConfCommitmentStore} from './interfaces/IPreConfirmations.sol';
import {IBidderRegistry} from './interfaces/IBidderRegistry.sol';


/// @title Oracle Contract
/// @author Kartik Chopra
/// @notice This contract is for fetching L1 Ethereum Block Data

/**
 * @title Oracle - A contract for Fetching L1 Block Builder Info and Block Data.
 * @dev This contract serves as an oracle to fetch and process Ethereum Layer 1 block data.
 */
contract Oracle is Ownable {
    /// @dev Maps builder names to their respective Ethereum addresses.
    mapping(string => address) public blockBuilderNameToAddress;

    /// @dev Stores the block number that is next in line to be requested.
    uint256 public nextRequestedBlockNumber;

    /**
     * @dev Returns the next block number that is set to be requested.
     */
    function getNextRequestedBlockNumber() external view returns (uint256) {
        return nextRequestedBlockNumber;
    }

    // To shutup the compiler
    /// @dev Empty receive function to silence compiler warnings about missing payable functions.
    receive() external payable {
        // Empty receive function
    }

    /**
     * @dev Fallback function to revert all calls, ensuring no unintended interactions.
     */
    fallback() external payable {
        revert("Invalid call");
    }

    /// @dev Reference to the PreConfCommitmentStore contract interface.
    IPreConfCommitmentStore private preConfContract;

    IBidderRegistry private bidderRegistry;

    /**
     * @dev Constructor to initialize the contract with a PreConfirmations contract.
     * @param _preConfContract The address of the pre-confirmations contract.
     * @param _nextRequestedBlockNumber The next block number to be requested.
     * @param _owner Owner of the contract, explicitly needed since contract is deployed with create2 factory.
     */
    constructor(
        address _preConfContract,
        address _bidderRegistry,
        uint256 _nextRequestedBlockNumber,
        address _owner
    ) Ownable() {
        preConfContract = IPreConfCommitmentStore(_preConfContract);
        bidderRegistry = IBidderRegistry(_bidderRegistry);
        nextRequestedBlockNumber = _nextRequestedBlockNumber;
        _transferOwnership(_owner);
    }

    /// @dev Event emitted when a commitment is processed.
    event CommitmentProcessed(bytes32 commitmentHash, bool isSlash);

    /**
     * @dev Allows the owner to add a new builder address.
     * @param builderName The name of the block builder as it appears on extra data.
     * @param builderAddress The Ethereum address of the builder.
     */
    function addBuilderAddress(string memory builderName, address builderAddress) external onlyOwner {
        blockBuilderNameToAddress[builderName] = builderAddress;
    }

    /**
     * @dev Returns the builder's address corresponding to the given name.
     * @param builderNameGrafiti The name (or graffiti) of the block builder.
     */
    function getBuilder(string calldata builderNameGrafiti) external view returns (address) {
        return blockBuilderNameToAddress[builderNameGrafiti];
    }

    // Function to receive and process the block data (this would be automated in a real-world scenario)
    /**
     * @dev Processes a builder's commitment for a specific block number.
     * @param commitmentIndex The id of the commitment in the PreConfCommitmentStore.
     * @param blockNumber The block number to be processed.
     * @param blockBuilderName The name of the block builder.
     * @param isSlash Determines whether the commitment should be slashed or rewarded.
     */
    function processBuilderCommitmentForBlockNumber(
        bytes32 commitmentIndex,
        uint256 blockNumber,
        string calldata blockBuilderName,
        bool isSlash
    ) external onlyOwner {
        // Check graffiti against registered builder IDs
        address builder = blockBuilderNameToAddress[blockBuilderName];
        
        IPreConfCommitmentStore.PreConfCommitment memory commitment = preConfContract.getCommitment(commitmentIndex);
        if (commitment.commiter == builder && commitment.blockNumber == blockNumber) {
                processCommitment(commitmentIndex, isSlash);
        }

    }

    /**
     * @dev Sets the next block number to be requested.
     * @param newBlockNumber The new block number to be set.
     */
    function setNextBlock(uint64 newBlockNumber) external onlyOwner {
        nextRequestedBlockNumber = newBlockNumber;
    }

    /**
     * @dev Increments the `nextRequestedBlockNumber` by one.
     */
    function moveToNextBlock() external onlyOwner {
        nextRequestedBlockNumber++;
    }

    /**
     */
    function unlockFunds(bytes32[] memory bidIDs) external onlyOwner {
        for (uint256 i = 0; i < bidIDs.length; i++) {
            bidderRegistry.unlockFunds(bidIDs[i]);
        }
    }

    /**
     * @dev Internal function to process a commitment, either slashing or rewarding based on the commitment's state.
     * @param commitmentIndex The id of the commitment to be processed.
     * @param isSlash Determines if the commitment should be slashed or rewarded.
     */
    function processCommitment(bytes32 commitmentIndex, bool isSlash) private {
        if (isSlash) {
            preConfContract.initiateSlash(commitmentIndex);
        } else {
            preConfContract.initateReward(commitmentIndex);
        }
        // Emit an event that a commitment has been processed
        emit CommitmentProcessed(commitmentIndex, isSlash);
    }
}

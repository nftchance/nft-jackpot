// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

/// @dev Base layer dependencies.
import { VRFConsumerBaseV2 } from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/// @dev Interfaces used in-processing.
import { VRFCoordinatorV2Interface } from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

contract JackpotRandomness is
    VRFConsumerBaseV2
{ 
    /// @dev The Chainlink coordinator address that generates randomness.
    VRFCoordinatorV2Interface private COORDINATOR;

    // @dev The Chainlink subscription id for the VRF request.
    uint64 public clSubscriptionId;
    
    /// @dev The amount of gas that is used to process and store each returned word.
    uint32 clCallbackGasLimitPerWinner = 20000;
    
    /// @dev The amount of confirmations the Oracle waits before responding.
    uint16 clRequestConfirmations = 3;
    
    /// @dev The gas lane used when responding to the VRF request.
    bytes32 internal clKeyHash;

    /// @dev fee paid in LINK to chainlink. 
    uint256 internal clFee;

    constructor(
          address _clCoordinator
        , bytes32 _clKeyHash
        , uint256 _clFee
    )
        VRFConsumerBaseV2(
              _clCoordinator
        )
    {
        clKeyHash = _clKeyHash;
        clFee = _clFee;
    }

    function _drawJackpot(
        uint32 _winners   
    )
        internal
        returns (
            uint256 requestId
        )
    { 
        requestId = COORDINATOR.requestRandomWords(
              clKeyHash
            , clSubscriptionId
            , clRequestConfirmations
            , clCallbackGasLimitPerWinner * _winners
            , _winners
        );
    }
}
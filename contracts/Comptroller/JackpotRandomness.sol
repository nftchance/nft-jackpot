// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

/// @dev Base layer dependencies.
import { VRFConsumerBaseV2 } from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/// @dev Interfaces used in-processing.
import { VRFCoordinatorV2Interface } from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import { LinkTokenInterface } from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

import { JackpotPrizePoolInterface } from "../PrizePool/interfaces/JackpotPrizePoolInterface.sol";

contract JackpotRandomness is
      VRFConsumerBaseV2
    , Ownable
{ 
    /// @dev The Chainlink coordinator address that generates randomness.
    VRFCoordinatorV2Interface private COORDINATOR;

    LinkTokenInterface private LINK;

    // @dev The Chainlink subscription id for the VRF request.
    uint64 public clSubscriptionId;
    
    /// @dev The amount of gas that is used to process and store each returned word.
    uint32 clCallbackGasLimitPerWinner = 20000;
    
    /// @dev The amount of confirmations the Oracle waits before responding.
    uint16 clRequestConfirmations = 3;
    
    /// @dev The gas lane used when responding to the VRF request.
    bytes32 internal clKeyHash;

    /// @dev Keeps tracking of which address a request id was for.
    mapping(uint256 => address) public requestIdsToPrizePoolAddresses;

    constructor(
          address _clCoordinator
        , address _clLinkToken
        , bytes32 _clKeyHash
    )
        VRFConsumerBaseV2(
              _clCoordinator
        )
    {
        clKeyHash = _clKeyHash;

        /// @dev Create existing connecting to the VRF interface.
        COORDINATOR = VRFCoordinatorV2Interface(_clCoordinator); 

        /// @dev Create existing connecting to the LINK interface.
        LINK = LinkTokenInterface(_clLinkToken);

        /// @dev Sets the subscription id for the VRF request.
        // clSubscriptionId = COORDINATOR.createSubscription();       

        /// @dev Enable this contract to request random numbers.
        // COORDINATOR.addConsumer(
        //       clSubscriptionId
        //     , address(this)
        // );
    }

    function createSubscriptionAndFund(
        uint96 amount
    ) 
        external 
    {
        if (clSubscriptionId == 0) {
            clSubscriptionId = COORDINATOR.createSubscription();
            COORDINATOR.addConsumer(clSubscriptionId, address(this));
        }
        
        LINK.transferAndCall(
            address(COORDINATOR),
            amount,
            abi.encode(clSubscriptionId)
        );
    }

    function fundSubscription(
        uint96 amount
    ) 
        external
    {
        LINK.transferAndCall(
            address(COORDINATOR),
            amount,
            abi.encode(clSubscriptionId)
        );
    }

    function cancelSubscription() 
        external
        virtual
        onlyOwner()
    {
        COORDINATOR.cancelSubscription(
              clSubscriptionId
            , msg.sender
        );

        clSubscriptionId = 0;
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

    function fulfillRandomWords(
          uint256 requestId
        , uint256[] memory _randomWords
    ) 
        internal 
        override
    {
        /// @dev Interface the relevant Prize Pool contract to run the processing.
        JackpotPrizePoolInterface prizePool = JackpotPrizePoolInterface(requestIdsToPrizePoolAddresses[requestId]);

        /// @dev Remove the request id from the list of pending VRF requests. 
        delete requestIdsToPrizePoolAddresses[requestId];

        /// @dev Run the processing of the Jackpot.
        prizePool.processJackpot(_randomWords);
    }
}

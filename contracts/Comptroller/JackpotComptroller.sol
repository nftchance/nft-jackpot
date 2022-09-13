// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

/// @dev Base layer dependencies.
import { JackpotComptrollerInterface } from "./interfaces/JackpotComptrollerInterface.sol";
import { JackpotRandomness } from "./JackpotRandomness.sol";

/// @dev Definition dependencies.
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { PRBMathSD59x18 } from "@prb/math/contracts/PRBMathSD59x18.sol";
import { JackpotPrizePoolInterface } from "../PrizePool/interfaces/JackpotPrizePoolInterface.sol";

/// @dev Helper libraries.
import { JackpotLibrary as JL } from "../Library/JackpotLibrary.sol"; 

import "hardhat/console.sol";

contract JackpotComptroller is
      JackpotComptrollerInterface
    , JackpotRandomness
{
    /// @dev Enables the usage of EIP-1167 Clones for Pool deployment.
    using Clones for address;

    /// @dev Enables the usage of PRBMathSD59x18 for fixed point math.
    using PRBMathSD59x18 for int256;

    /// @dev Existing interface to the Prize Pool implementation.
    JackpotPrizePoolInterface PRIZE_POOL;

    address public prizePoolImplementation;

    /// @dev Mapping that allows access to the Jackpot drawing for a given address.
    mapping(address => bool) public isPrizePool;

    /// @dev Announces that a new Jackpot has been opened.
    event JackpotOpened(address prizePool);

    constructor(
          address _clCoordinator
        , address _clLinkToken
        , bytes32 _clKeyHash
    )
        JackpotRandomness(
              _clCoordinator
            , _clLinkToken
            , _clKeyHash
        )
    { }

    /**
     * @dev Prevents anyone besides a prize pool from calling a function.
     */
    modifier onlyPrizePool() {
        require(
              isPrizePool[msg.sender]
            , "JackpotComptroller::onlyPrizePool: Sender is not a Prize Pool."
        );
        _;
    }

    /**
     * @dev Sets the prize pool implementation for future Jackpot deployments.
     * @param _prizePoolImplementation The address of the prize pool implementation.
     * 
     * Requirements:
     * - The prize pool implementation must be a Jackpot contract.
     */
    function _setPrizePoolImplementation(
        address _prizePoolImplementation
    ) 
        internal 
    {
        /// @dev Confirm that the proper interface is setup.
        JackpotPrizePoolInterface prizePool = JackpotPrizePoolInterface(_prizePoolImplementation);

        /// @dev Save the address that is used for the implementation so that
        ///      it can be used to create new Prize Pools.
        prizePoolImplementation = _prizePoolImplementation;

        /// @dev Create an interface to the Prize Pool implementation.
        PRIZE_POOL = prizePool;
    }

    /**
     * @dev Opens a new Jackpot contract, defines the constants, qualifiers and
     *      accepts the starting collateral.
     * @param _stateSchema The state schema for the Jackpot.
     * @param _jackpotSchema The jackpot schema for the Jackpot.
     */ 
    function _openJackpot(
          JL.JackpotStateSchema calldata _stateSchema
        , JL.JackpotSchema calldata _jackpotSchema
    ) 
        internal
    { 
        /// @dev Deploy EIP-1167 Minimal Proxy clone of PrizePool.
        address payable prizePoolAddress = payable(prizePoolImplementation.clone());

        /// @dev Interface with the newly created pool.
        JackpotPrizePoolInterface prizePool = JackpotPrizePoolInterface(prizePoolAddress);

        /// @dev Deploy the clone contract to serve as the Prize Pool.
        prizePool.initialize(
              msg.sender
            , address(this)
            , _stateSchema
            , _jackpotSchema
        );

        /// @dev Add this contract as an allowed caller of Randomness.
        isPrizePool[prizePoolAddress] = true;
    }

    /**
     * @notice This function is called by the PrizePool to request a random number from Chainlink.
     * @param _winners The number of winners to be drawn.
     * @return requestId The ID of the Chainlink VRF request.
     * @notice While this function may appear to be exposed to the public here, the callable 
     *         implementation is only accessible from the PrizePool to minimize the amount of
     *         data that needs to be stored.
     */
    function drawJackpot(
        uint32 _winners
    )
        override
        external
        virtual 
        onlyPrizePool()
        returns (
            uint256 requestId
        )
    {
        /// @dev Submit the request for randomness.
        requestId = _drawJackpot(_winners);

        /// @dev Save the request id to the Prize Pool address.
        requestIdsToPrizePoolAddresses[requestId] = msg.sender;
    }
}
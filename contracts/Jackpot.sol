// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

/**
 * @title Jackpot
 * @dev A contract that allows for the creation of a jackpot.
 */

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Comptroller/JackpotComptroller.sol";

contract Jackpot is
      JackpotComptroller
{
    /// @dev Enables the usage of PRBMathSD59x18 for fixed point math.
    using PRBMathSD59x18 for int256;

    constructor(
          address _prizePoolImplementation
        , address _coordinator
        , address _linkToken
        , bytes32 _keyHash
    ) 
        JackpotComptroller(
              _coordinator
            , _linkToken
            , _keyHash
        )
    { 
        _setPrizePoolImplementation(_prizePoolImplementation);
    }

    /**
     * See {JackpotComptroller._setPrizePoolImplementation}.
     * 
     * Public Requirements:
     * - The caller must be the owner of the contract.
     */
    function setPrizePoolImplementation(
        address _prizePoolImplementation
    ) 
        public
        onlyOwner()
    {
        _setPrizePoolImplementation(_prizePoolImplementation);
    }

    function _packState(
          uint256 _started
        , uint256 _status
        , uint256 _requiredQualifiers
        , uint256 _max
        , uint256 _cancelTime
        , uint256 _endTime
        , uint256 _fingerprintDecay
    )
        internal
        pure
        returns (
            uint256 state
        )
    {
        /// @dev Start 3 bits over to account for `started` and `status` both as zero.

        state |= _requiredQualifiers << 3;
        state |= _max << 11;
        state |= _cancelTime << 19;
        state |= _endTime << 51;
        state |= _fingerprintDecay << 83;
    }

    /**
     * See {JackpotComptroller._openJackpot}.
     */
    function openJackpot(
          uint256 _requiredQualifiers
        , uint256 _max
        , uint256 _cancelTime
        , uint256 _endTime
        , uint256 _fingerprintDecay        
        , JL.JackpotSchema memory _jackpotSchema
    )
        public
    { 
        uint32 now = uint32(block.timestamp);

        require(
              _cancelTime > now
            , "Jackpot::openJackpot: cancel time must be in the future."
        );

        require(
              _endTime > now
            , "Jackpot::openJackpot: end time must be in the future."   
        );

        uint256 stateSchema = _packState(
              0
            , 0                                     // Start every Jackpot in the seeded state.
            , _requiredQualifiers
            , _max
            , _cancelTime
            , _endTime
            , _fingerprintDecay
        );

        _jackpotSchema.state = stateSchema;

        _openJackpot(
            _jackpotSchema
        ); 
    }
}
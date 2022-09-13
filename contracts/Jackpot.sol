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

    /**
     * See {JackpotComptroller._openJackpot}.
     */
    function openJackpot(
          JL.JackpotStateSchema calldata _stateSchema
        , JL.JackpotSchema calldata _jackpotSchema
    )
        public
        payable
    { 
        uint32 now = uint32(block.timestamp);

        require(
              _stateSchema.cancelTime > now
            , "Jackpot::openJackpot: cancel time must be in the future."
        );

        require(
              _stateSchema.endTime > now
            , "Jackpot::openJackpot: end time must be in the future."   
        );

        _openJackpot(
              _stateSchema
            , _jackpotSchema
        ); 
    }
}
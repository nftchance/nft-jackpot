// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

/**
 * @title Jackpot
 * @dev A contract that allows for the creation of a jackpot.
 */

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./JackpotComptroller.sol";

contract Jackpot is
    JackpotComptroller
{
    constructor(
          address _coordinator
        , address _linkToken
        , bytes32 _keyHash
        , uint256 _fee
    ) 
        JackpotComptroller(
              _coordinator
            , _linkToken
            , _keyHash
            , _fee
        )
    { }

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
          JackpotConstantSchema _constants
        , JackpotQualifierSchema[] calldata _qualifiers
    ) 
        public 
        payable 
    { 
        require(
              _constants.cancelTime > int256(block.timestamp).toInt()
            , "Jackpot::openJackpot: cancel time must be in the future."
        );

        require(
              _constants.endTime > int256(block.timestamp).toInt()
            , "Jackpot::openJackpot: end time must be in the future."   
        );

        // require(
        //     msg.value >= _constants.startingCollateral
        //     , "Jackpot::openJackpot: insufficient collateral."
        // );

        _openJackpot(
              _constants
            , _qualifiers
            , _cancelTime
        );
    }

    function drawJackpot(
        uint256 _jackpotId
    ) 
        public 
    { 
        _drawJackpot(_jackpotId);
    }
}
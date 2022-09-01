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

    function getJackpot(
        uint256 _jackpotId
    )
        public
        view
        returns (JackpotSchema jackpotSchema)
    { }

    function getEntry(
          uint256 _jackpotId
        , uint256 _entryId
    ) 
        public 
        view
        returns (JackpotEntrySchema entrySchema) 
    { }

    function openJackpot(
          JackpotConstantSchema _constants
        , JackpotQualifierSchema[] calldata _qualifiers
        , uint256 _cancelTime
    ) public payable { 
        _openJackpot(
              _constants
            , _qualifiers
            , _cancelTime
        );
    }

    function abortJackpot(
        uint256 _jackpotId
    ) 
        public 
    { 
        _abortJackpot(_jackpotId);
    }

    function fundJackpot(
          uint256 _jackpotId
        , CollateralSchema[] calldata _collateral
    ) 
        public 
        payable 
    {
        _fundJackpot(_collateral);
    }

    function openEntryEmpty(
        uint256 _quantity
    ) 
        public
        payable
    {
        _openEntryEmpty(_quantity);
    }

    function openEntryBacked(
          CollateralSchema[] calldata _collateral
        , uint256 _quantity
    ) 
        public
        payable
    { 
        _openEntryBacked(
              _collateral
            , _quantity
        );
    }

    function openEntrySignature(
          bytes calldata signature
        , uint256 _quantity
    ) 
        public
    {
        _openEntrySignature(
              signature
            , _quantity
        );
    }

    function abortEntry(
          uint256 _jackpotId
        , uint256 _entryId
    ) 
        public 
    {
        _abortEntry(
              _jackpotId
            , _entryId
        );
    }

    function drawJackpot(
        uint256 _jackpotId
    ) 
        public 
    { 
        _drawJackpot(_jackpotId);
    }

    function terminateJackpot(
        uint256 _jackpotId
    ) 
        public 
    {
        _terminateJackpot(_jackpotId);
    }

    function claimJackpot(
          uint256 _jackpotId
        , uint256 _entryId
    ) public { 
        _claimJackpot(
              _jackpotId
            , _entryId
        );
    }

    function claimRefund(
          uint256 _jackpotId
        , uint256 _entryId
    ) public { 
        _claimRefund(
              _jackpotId
            , _entryId
        );
    }
}
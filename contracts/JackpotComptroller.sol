// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

import "./JackpotGreeks.sol";

contract JackpotComptroller is
      JackpotGreeks
    , VRFConsumerBase 
{

    bytes32 internal keyHash; // chainlink
    uint256 internal fee; // fee paid in LINK to chainlink. (0.1 in Rinkeby, 2 in Mainnet)

    constructor(
          address _coordinator
        , address _linkToken
        , bytes32 _keyHash
        , uint256 _fee
    )
        VRFConsumerBase(
              _coordinator
            , _linkToken
        )
    {
        require(_coordinator != address(0));
        require(_linkToken != address(0));
        require(_keyHash != bytes32(0));
        require(_fee != 0);

        keyHash = _keyHash;
        fee = _fee;
    }

    function _openJackpot(
          JackpotConstantSchema _constants
        , JackpotQualifierSchema[] calldata _qualifiers
        , uint256 _cancelTime
    ) 
        internal
    { 

    }

    function _abortJackpot(
        uint256 _jackpotId
    ) 
        internal 
    { 

    }

    function _fundJackpot(
          uint256 _jackpotId
        , CollateralSchema[] calldata _collaterals
    ) 
        internal 
    { 

    }

    function _openEntryEmpty(
          uint256 _jackpotId
    ) 
        internal 
    { 

    }

    function _openEntryBacked(
        uint256 _jackpotId
        , CollateralSchema[] calldata _collaterals
    ) 
        internal 
    { 

    }

    function _openEntrySignature(
          uint256 _jackpotId
        , bytes calldata _signature
    ) 
        internal 
    { 

    }

    function _abortEntry(
        uint256 _jackpotId
        , uint256 _entryId
    ) 
        internal 
    { 

    }

    function _drawJackpot(
        uint256 _jackpotId
    ) 
        internal 
    { 

    }

    function _terminateJackpot(
        uint256 _jackpotId
    ) 
        internal 
    { 

    }

    function _claimJackpot(
        uint256 _jackpotId
    ) 
        internal 
    { 

    }

    function _claimRefund(
        uint256 _jackpotId
    ) 
        internal 
    { 

    }
}

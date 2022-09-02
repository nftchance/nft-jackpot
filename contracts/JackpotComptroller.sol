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
        // Create data sturcture in the Jackpot registry
    }

    function _abortJackpot(
        uint256 _jackpotId
    ) 
        internal 
    { 
        // Confirm the Jackpot is open.
        // Confirm the sender is the seeder.
        // Mark Jackpot as aborted.
        // Withdraw all collateral.
    }

    function _fundJackpot(
          uint256 _jackpotId
        , CollateralSchema[] calldata _collaterals
    ) 
        internal 
    { 
        // Confirm that the jackpot can be funded.
        // Confirm that the jackpot has not already been drawn.
    }

    function _openEntry(
        bytes calldata _fingerprint
    )
        internal
        payable
    { 
        // Verify that the fingerprint decay is at zero.
        // Confirm the message value is sufficient to cover quantity.
    }

    function _openEntryEmpty(
          uint256 _jackpotId
    ) 
        internal
        payable
    { 
        // Confirm that the Jackpot is open.
        // Use wallet address as fingerprint.
    }

    function _openEntryBacked(
        uint256 _jackpotId
        , CollateralSchema[] calldata _collaterals
    ) 
        internal
        payable 
    { 
        // Confirm that the jackpot is open.
        // Confirm that the collateral meets the qualifiers set.
        // If more than one qualifier is required, then while loop until meeting the 
        // requirements of all qualifiers otherwise revert.
        // Confirm that the collateral fingerprint decay is at 0.
            // Proceed with normal entry opening however we cannot use the _openEntry
            // as everything will have to be done inline in this function to avoid an extra for loop.
        // Confirm the message value is sufficient to cover quantity.
    }

    function _openEntrySignature(
          uint256 _jackpotId
        , bytes calldata _signature
    ) 
        internal
        payable 
    { 
        // Confirm that the Jackpot is open.
        // Confirm that the signature is valid.
        // Proceed with normal entry opening.
    }

    function _abortEntry(
        uint256 _jackpotId
        , uint256 _entryId
    ) 
        internal 
    { 
        // Confirm that the sender is the owner of the entry.
        // Confirm that the jackpot is not already drawn.
        // Confirm that the entry is not already aborted.
        // Determine what amount of refund is owed with the following logic:
        // refund = amountDeposited * (1 - block.timestamp / drawTime)
        // Transfer the refund to the entry owner.
        // Delete the entry in the array.
        // Update the tail of .entries to have the proper ending index. 
    }

    function _drawJackpot(
        uint256 _jackpotId
    ) 
        internal 
    { 
        // Confirm that the jackpot is ready to be drawn
        // Confirm that the jackpot is not already drawn
        // Confirm that the jackpot is not already aborted
        // Use Chainlink to get the winner.
        // Store chainlink request ID in mapping pointing to Jackpot.
    }

    function _terminateJackpot(
        uint256 _jackpotId
    ) 
        internal 
    { 
        // Confirm that the sender is the seeder of the jackpot.
        // Confirm that the jackpot is in the open state.
        // Set the state to choosing winner.
        // Use Chainlink to get the winner.
        // Store chainlink request ID in mapping pointing to Jackpot.
    }

    function _claimJackpot(
          uint256 _jackpotId
        , uint256 _entryId
    ) 
        internal 
    { 
        // Confirm that the sender is the owner of the entry.
        // Confirm that the entry is the winner.
        // Transfer the prize associated to this entry id to the sender.
    }

    function _claimRefund(
          uint256 _jackpotId
        , uint256 _entryId
    ) 
        internal 
    { 
        // Confirm that the sender is the owner of the entry.
        // Determine how much of a refund is owed for this entry.
        // Transfer the refund to the entry owner.
    }
}

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

library JackpotLibrary { 
    /// All the different status a raffle can have
    enum STATUS {
        CREATED, // the operator creates the raffle
        ACCEPTED, // the seller stakes the nft for the raffle
        EARLY_CASHOUT, // the seller wants to cashout early
        CANCELLED, // the operator cancels the raffle and transfer the remaining funds after 30 days passes
        CLOSING_REQUESTED, // the operator sets a winner
        ENDED, // the raffle is finished, and NFT and funds were transferred
        CANCEL_REQUESTED // operator asks to cancel the raffle. Players has 30 days to ask for a refund
    }

    struct JackpotConstantSchema {
        /// @dev Prevent the same token from being used in quick succession.
        int256 fingerprintDecayConstant;
        /// @dev GDA implementation for seeder controlled entry pricing.
        int256 priceInitial;
        int256 priceScaleConstant;
        int256 priceDecayConstant;
        int256 startTime;
        /// @dev Enabling permisionsless and non-oracle running jackpot distribution.
        int256 cancelTime;
        int256 endTime;
    }

    struct JackpotQualifierSchema { 
        address token;
        uint256 quantity;
        uint256 max;
    }

    struct CollateralSchema {
        address token; 
        uint256 id;
    }

    struct JackpotEntrySchema {
        address buyer; 
        uint256 quantity;
        uint256 tail;
    }

    struct JackpotSchema { 
        JackpotConstantSchema constants;
        JackpotQualifierSchema[] qualifiers;
        address prizePool;
        uint256 winner;
        int256 cancelTime;
    }
}
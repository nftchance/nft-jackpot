// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

library JackpotLibrary { 
    ///@dev All the different status a raffle can have
    enum STATUS {
          /// @dev The Jackpot is open for entries. (has provided collateral)
          SEEDED
          /// @dev The seeder cancels the Jackpot if minimum funds are not met before the cancel time.
        , ABORTED 
          /// @dev A request for randomness has been made.
        , DRAWING
          /// @dev The winners of a Prize Pool have been chosen.
        , ENDED // the raffle is finished, and NFT and funds were transferred
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
        uint256 value;
        uint256 tail;
    }

    struct JackpotSchema { 
        STATUS status;
        JackpotConstantSchema constants;
        JackpotQualifierSchema[] qualifiers;
        address prizePool;
        uint256[] winners;
        int256 cancelTime;
    }
}
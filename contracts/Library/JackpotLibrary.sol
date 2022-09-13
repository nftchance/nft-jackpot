// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

library JackpotLibrary { 
    ///@dev All the different status a raffle can have
    enum STATUS {
          SEEDED
        , ABORTED 
        , DRAWING                           // 
        , ENDED                             // the raffle is finished, and NFT and funds were transferred
    }

    enum TOKEN_TYPE {
          ERC20
        , ERC721
        , ERC1155
    }

    struct JackpotStateSchema {             // Bitpacked into a single uint128 
        bool started;                       // 001 (controls if entry opening has began)
        STATUS status;                      // 002 (0: SEEDED, 1: ABORTED, 2: DRAWING, 3: ENDED)
        uint8 requiredQualifiers;           // 008 (number of qualifiers required to win) 
        uint8 max;                          // 008 (max number of entries each fingerprint can claim)
        uint32 cancelTime;                  // 032 (time at which the Jackpot is cancelled)
        uint32 endTime;                     // 032 (time at which the Jackpot is ended and goes to drawing)
        uint32 fingerprintDecay;            // 032 (constant used to decay the fingerprint)
    }                                       // 128 bits

    /// @dev The less than ideal requirement of uint256 for the `aux` field is due to the fact that
    ///      ERC1155 tokens can have a quantity of 2^256 - 1. This is not a problem for ERC721 or
    ///      ERC20 tokens, but it is a problem for ERC1155 tokens. This is the only way to support
    ///      all three token types in a single struct. 
    struct JackpotTokenSchema { 
        TOKEN_TYPE tokenType;               // 002 (0: ERC20, 1: ERC721, 2: ERC1155)
        address token;                      // 020 (the address of the token to use for this qualifier)
        uint256 id;                         // 256 (the ID of the token to use for this qualifier)
        uint256 aux;                        // 256 (a trailing to identify `quantity` or `id`)
    }                                       // 276 bits

    struct JackpotPrizeSchema { 
        uint256 value;                      // 256 (the amount of ETH associated to this prize)                              
        JackpotTokenSchema[] collateral;    // 276 * n (the erc collateral to be used for this prize)
    }                                       // 256 + 276 * n bits

    struct JackpotEntrySchema {
        address buyer;                      // 020 (the address of the buyer)
        uint32 tail;                        // 032 (the id of the last entry that was purchased)
    }                                       // 276 bits

    struct JackpotSchema { 
        uint256 price;                      // 256 (the price of an entry)
        uint256 state;                      // 256 (bitpacked state of the Jackpot)
        uint32[] qualifiers;                // 032 * n (the bitpacked qualifiers for this Jackpot)
        uint32[] winners;                   // 032 * n (the winners of this Jackpot)
    }
}
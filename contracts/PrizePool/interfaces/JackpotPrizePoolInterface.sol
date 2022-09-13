// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import { JackpotLibrary as JL } from "../../Library/JackpotLibrary.sol";

interface JackpotPrizePoolInterface { 
    function initialize(
              address _seeder        
            , address _comptroller
            , JL.JackpotSchema memory _jackpotSchema
        ) 
            external
            payable;

    function fundJackpot(
        JL.JackpotTokenSchema[] calldata _collateral
    ) 
        external
        payable;

    function abortJackpot()
        external;

    function drawJackpot() 
        external
        returns (
            uint256 requestId
        );

    function processJackpot(
        uint256[] calldata _randomWords
    )
        external;
}
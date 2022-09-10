// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import { JackpotLibrary as JL } from "../../Library/JackpotLibrary.sol";

interface JackpotPrizePoolInterface { 
    function initialize(
              address _seeder        
            , address _comptroller
            , JL.JackpotConstantSchema calldata _constants
            , JL.JackpotQualifierSchema[] calldata _qualifiers
            , JL.CollateralSchema[] calldata _collateral
        ) 
            external
            payable;

    function fundJackpot(
        JL.CollateralSchema[] calldata _collateral
    ) 
        external;

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
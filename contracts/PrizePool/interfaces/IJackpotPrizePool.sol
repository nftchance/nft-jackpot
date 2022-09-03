// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import { JackpotLibrary as JL } from "../../Library/JackpotLibrary.sol";

interface IJackpotPrizePool { 
    function fundJackpot(
        JL.CollateralSchema[] calldata _collateral
    ) 
        external;
}
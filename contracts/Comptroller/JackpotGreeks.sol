// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import { JackpotLibrary as JL } from "../Library/JackpotLibrary.sol"; 

import {PRBMathSD59x18} from "@prb/math/contracts/PRBMathSD59x18.sol";

contract JackpotGreeks {
    using PRBMathSD59x18 for int256;

    function _getPrice(
         uint256 _quantity
    )     
        internal
        view
        returns (uint256)
    {
        return 0;
    }
}
// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import { JackpotLibrary as JL } from "./Library/JackpotLibrary.sol"; 

import {PRBMathSD59x18} from "@prb/math/contracts/PRBMathSD59x18.sol";

contract JackpotGreeks {
    using PRBMathSD59x18 for int256;

    // Delta	Option price	Value of underlying asset
    // Gamma	Delta	Value of underlying asset
    // Vega	Option price	Volatility
    // Theta	Option price	Time to maturity
    // Rho	Option price	Interest rate

    JL.JackpotSchema[] public jackpots;

    function _getPrice(
          uint256 _jackpotId
        , uint256 _quantity
    )     
        internal
        view
        returns (uint256)
    {
        JL.JackpotConstantSchema constants = jackpots[_jackpotId].constants;

        int256 quantity = int256(_quantity).fromInt();
        // int256 numSold = int256(currentId).fromInt();
        int256 timeSinceStart = int256(block.timestamp).fromInt() - constants.startTime;

        int256 num1 = constants.priceInitial.mul(constants.scaleFactor.pow(numSold));
        int256 num2 = constants.scaleFactor.pow(quantity) - PRBMathSD59x18.fromInt(1);
        int256 den1 = constants.decayConstant.mul(timeSinceStart).exp();
        int256 den2 = constants.scaleFactor - PRBMathSD59x18.fromInt(1);
        int256 totalCost = num1.mul(num2).div(den1.mul(den2));
        //total cost is already in terms of wei so no need to scale down before
        //conversion to uint. This is due to the fact that the original formula gives
        //price in terms of ether but we scale up by 10^18 during computation
        //in order to do fixed point math.
        return uint256(totalCost);
    }
}
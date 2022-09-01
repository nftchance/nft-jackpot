// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import {JackpotTails} from "./JackpotTails.sol";

import {PRBMathSD59x18} from "@prb/math/contracts/PRBMathSD59x18.sol";

contract JackpotGreeks is
    JackpotTails
{
    using PRBMathSD59x18 for int256;

    // Delta	Option price	Value of underlying asset
    // Gamma	Delta	Value of underlying asset
    // Vega	Option price	Volatility
    // Theta	Option price	Time to maturity
    // Rho	Option price	Interest rate

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
        int256 endTime;
        /// @dev Adds support for falling returns as draw-time approaches.
        int256 refundFactorDecay;
    }

    struct JackpotQualifierSchema { 
        address token;
        uint256 quantity;
        uint256 max;
    }

    struct JackpotEntrySchema {
        address buyer; 
        uint256 quantity;
        uint256 tail;
    }

    struct JackpotSchema { 
        STATUS status;
        JackpotConstantSchema constants;
        JackpotQualifierSchema[] qualifiers;
        address prizePool;
        uint256 winner;
        int256 cancelTime;
    }

    JackpotSchema[] public jackpots;

    function _getPrice(
          uint256 _jackpotId
        , uint256 _quantity
    )     
        internal
        view
        returns (uint256)
    {
        JackpotConstantSchema constants = jackpots[_jackpotId].constants;

        int256 quantity = int256(_quantity).fromInt();
        int256 numSold = int256(currentId).fromInt();
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

    function _getRefund(
        uint256 _quantity
    )     
        public
        pure
        returns (uint256)
    {
        return _quantity;
    }
}
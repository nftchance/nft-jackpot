// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import { JackpotGreeks } from "./JackpotGreeks.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { VRFConsumerBase } from "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

import { IJackpotPrizePool } from "./PrizePool/interfaces/IJackpotPrizePool.sol";

contract JackpotComptroller is VRFConsumerBase {
    using Clones for address;

    bytes32 internal keyHash; // chainlink
    uint256 internal fee; // fee paid in LINK to chainlink. (0.1 in Rinkeby, 2 in Mainnet)

    address public prizePoolImplementation;

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

        _setPrizePoolImplementation(_prizePoolImplementation); 
    }

    /**
     * @dev Sets the prize pool implementation for future Jackpot deployments.
     * @param _prizePoolImplementation The address of the prize pool implementation.
     */
    function _setPrizePoolImplementation(
        address _prizePoolImplementation
    ) 
        internal 
    {
        prizePoolImplementation = _prizePoolImplementation;
    }

    /**
     * @dev Opens a new Jackpot contract, defines the constants, qualifiers and
     *      accepts the starting collateral.
     * @param _constants The mathematical constants that control the Jackpot rules.
     * @param _qualifiers An array of qualifying metrics that allow an individual to 
     *                    buy or claim an entry for the Jackpot.
     * @param _collateral An array of tokens and associated token ids / quantities that 
     *                    being supplied as collateral for this Jackpot.
     * @param _cancelTime The time at which refunds were enabled for a Jackpot.
     * @notice The `cancelTime` is the only parameter that is not immutable. It is used to
     *         allow the seeder to close the Jackpot early if the minimum funding is not
     *         reached.
     * @notice No measure of on-chain indexing is in state to keep this as cheap as possible,
     *         meaning there is no on-chain enumerable list of jackpots. Extreme measures are 
     *         taken as the rest of the processing is extremely expensive.
     */ 
    function _openJackpot(
          JackpotConstantSchema _constants
        , JackpotQualifierSchema[] calldata _qualifiers
        , CollateralSchema[] calldata _collateral
        , uint256 _cancelTime
    ) 
        internal
        returns (IJackpotPrizePool prizePool)
    { 
        /// @dev Deploy EIP-1167 Minimal Proxy clone of PrizePool.
        prizePool = IJackpotPrizePool(masterContract.clone());

        /// @dev Initialize PrizePool to the seeder with all needed information with the pool.
        IJackpotPrizePool(prizePool).initialize(
              _msgSender()
            , this
            , _constants
            , _qualifiers
            , _collateral
            , _cancelTime
        );

        /// @dev Emit event with the address of the PrizePool. (Used for at-time indexing.)
        emit JackpotCreated(address(prizePool));
    }
}

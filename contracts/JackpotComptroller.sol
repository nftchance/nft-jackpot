// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

/// @dev Base layer dependencies
import { VRFConsumerBase } from "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

/// @dev Runtime dependencies
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { JackpotLibrary as JL } from "./Library/JackpotLibrary.sol"; 
import { IJackpotPrizePool } from "./PrizePool/interfaces/IJackpotPrizePool.sol";

contract JackpotComptroller is
    VRFConsumerBase
{
    /// @dev Enables the usage of EIP-1167 Clones for Pool deployment.
    using Clones for address;

    /// @dev The randomnes key for Chainlink.
    bytes32 internal keyHash;
    /// @dev fee paid in LINK to chainlink. (0.1 in Rinkeby, 2 in Mainnet)
    uint256 internal fee;

    /// @dev The address of the Prize Pool implementation that is used when opening a Jackpot.
    address public prizePoolImplementation;

    mapping(bytes32 => address) public requestIdsToPrizePoolAddresses;

    event JackpotOpened(address prizePool);

    constructor(
          address _prizePoolImplementation
        , address _coordinator
        , address _linkToken
        , bytes32 _keyHash
        , uint256 _fee
    )
        VRFConsumerBase(
              _coordinator
            , _linkToken
        )
    {
        _setPrizePoolImplementation(_prizePoolImplementation); 

        keyHash = _keyHash;
        fee = _fee;
    }

    /**
     * @dev Sets the prize pool implementation for future Jackpot deployments.
     * @param _prizePoolImplementation The address of the prize pool implementation.
     * 
     * Requirements:
     * - The prize pool implementation must be a Jackpot contract.
     */
    function _setPrizePoolImplementation(
        address _prizePoolImplementation
    ) 
        internal 
    {
        require(
              IJackpotPrizePool(_prizePoolImplementation).isJackpot()
            , "Jackpot::setPrizePoolImplementation: must be a Jackpot contract."
        );

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
          JL.JackpotConstantSchema calldata _constants
        , JL.JackpotQualifierSchema[] calldata _qualifiers
        , JL.CollateralSchema[] calldata _collateral
        , uint256 _cancelTime
    ) 
        internal
        returns (IJackpotPrizePool prizePool)
    { 
        /// @dev Deploy EIP-1167 Minimal Proxy clone of PrizePool.
        prizePool = IJackpotPrizePool(payable(prizePoolImplementation.clone()));

        /// @dev Initialize PrizePool to the seeder with all needed information with the pool.
        IJackpotPrizePool(prizePool).initialize(
              msg.sender
            , this
            , _constants
            , _qualifiers
            , _collateral
        );

        /// @dev Emit event with the address of the PrizePool. (Used for at-time indexing.)
        emit JackpotOpened(address(prizePool));
    }

    function _drawJackpot(

    )
        external 
        returns (
            bytes32 requestId
        )
    {
        require(
              LINK.balanceOf(address(this)) >= fee
            , "Jackpot::drawJackpot: not enough LINK - fill contract with faucet"
        );

        requestId = requestRandomness(
              keyHash
            , fee
        );

        requestIdsToPrizePoolAddresses[requestId] = msg.sender;
    }

    function drawJackpot()
        external
        returns (
            bytes32 requestId
        )
    {
        require(
              LINK.balanceOf(address(this)) >= fee
            , "Jackpot::requestRandomness: not enough LINK - fill contract with faucet"
        );

        // TODO: Make sure the caller (the contract) is a PrizePool consumer deployed by this contract. 

        requestId = requestRandomness(
              keyHash
            , fee
        );

        requestIdsToPrizePoolAddresses[requestId] = msg.sender;
    }

    function fulfillRandomWords(
          uint256 requestId
        , uint256[] memory _randomWords
    ) 
        internal 
        override
    {
        /// @dev Interface the relevant Prize Pool contract to run the processing.
        IJackpotPrizePool prizePool = IJackpotPrizePool(requestIdsToPrizePoolAddresses[requestId]);

        /// @dev Remove the request id from the list of pending VRF requests. 
        delete requestIdsToPrizePoolAddresses[requestId];

        /// @dev Run the processing of the Jackpot.
        prizePool.processJackpot(_randomWords);
    }
}

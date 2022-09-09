// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

/// @dev Base layer dependencies.
import { JackpotRandomness } from "./JackpotRandomness.sol";

/// @dev Definition dependencies.
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { PRBMathSD59x18 } from "@prb/math/contracts/PRBMathSD59x18.sol";
import { IJackpotPrizePool } from "../PrizePool/interfaces/IJackpotPrizePool.sol";

/// @dev Helper libraries.
import { JackpotLibrary as JL } from "../Library/JackpotLibrary.sol"; 

contract JackpotComptroller is
    JackpotRandomness
{
    /// @dev Enables the usage of EIP-1167 Clones for Pool deployment.
    using Clones for address;

    /// @dev Enables the usage of PRBMathSD59x18 for fixed point math.
    using PRBMathSD59x18 for int256;

    struct JackpotRegistration { 
        bool isJackpot;
        uint256 randomnessRequestId;
    }

    /// @dev The address of the Prize Pool implementation that is used when opening a Jackpot.
    address public prizePoolImplementation;

    /// @dev Existing interface to the Prize Pool implementation.
    IJackpotPrizePool PRIZE_POOL;

    /// @dev Mapping that allows access to the Jackpot drawing for a given address.
    mapping(address => bool) public isPrizePool;

    /// @dev Announces that a new Jackpot has been opened.
    event JackpotOpened(address prizePool);

    constructor(
          address _prizePoolImplementation
        , address _clCoordinator
        , bytes32 _clKeyHash
        , uint256 _clFee
    )
        JackpotRandomness(
              _clCoordinator
            , _clKeyHash
            , _clFee
        )
    {
        _setPrizePoolImplementation(_prizePoolImplementation); 
    }

    modifier onlyPrizePool() {
        require(
              isPrizePool[msg.sender]
            , "JackpotComptroller::onlyPrizePool: Sender is not a Prize Pool."
        );
        _;
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
        /// @dev Confirm that the proper interface is setup.
        IJackpotPrizePool prizePool = IJackpotPrizePool(_prizePoolImplementation);

        /// @dev Save the address that is used for the implementation so that
        ///      it can be used to create new Prize Pools.
        prizePoolImplementation = _prizePoolImplementation;

        /// @dev Create an interface to the Prize Pool implementation.
        PRIZE_POOL = prizePool;
    }

    /**
     * @dev Opens a new Jackpot contract, defines the constants, qualifiers and
     *      accepts the starting collateral.
     * @param _constants The mathematical constants that control the Jackpot rules.
     * @param _qualifiers An array of qualifying metrics that allow an individual to 
     *                    buy or claim an entry for the Jackpot.
     * @param _collateral An array of tokens and associated token ids / quantities that 
     *                    being supplied as collateral for this Jackpot.
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
    ) 
        internal
        returns (IJackpotPrizePool prizePool)
    { 
        /// @dev Deploy EIP-1167 Minimal Proxy clone of PrizePool.
        address payable prizePoolAddress = payable(prizePoolImplementation.clone());

        /// @dev Interface with the newly created pool.
        prizePool = IJackpotPrizePool(prizePoolAddress);

        /// @dev Initialize PrizePool to the seeder with all needed information with the pool.
        prizePool.initialize(
              msg.sender
            , address(this)
            , _constants
            , _qualifiers
            , _collateral
        );

        /// @dev Add this contract as an allowed caller of Randomness.
        isPrizePool[prizePoolAddress] = true;

        /// @dev Emit event with the address of the PrizePool. (Used for at-time indexing.)
        emit JackpotOpened(prizePoolAddress);
    }

    function drawJackpot(
        uint32 _winners
    )
        external
        onlyPrizePool()
    {
        /// @dev Submit the request for randomness.
        uint256 requestId = _drawJackpot(_winners);

        /// @dev Save the request id to the Prize Pool address.
        requestIdsToPrizePoolAddresses[requestId] = msg.sender;
    }
}
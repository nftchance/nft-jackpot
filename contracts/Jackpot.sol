// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

/**
 * @title Jackpot
 * @dev A contract that allows for the creation of a jackpot.
 */

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Comptroller/JackpotComptroller.sol";

contract Jackpot is
      JackpotComptroller
{
    /// @dev Enables the usage of PRBMathSD59x18 for fixed point math.
    using PRBMathSD59x18 for int256;

    constructor(
          address _prizePoolImplementation
        , address _coordinator
        , address _linkToken
        , bytes32 _keyHash
    ) 
        JackpotComptroller(
              _coordinator
            , _linkToken
            , _keyHash
        )
    { 
        _setPrizePoolImplementation(_prizePoolImplementation);
    }

    /**
     * See {JackpotComptroller._setPrizePoolImplementation}.
     * 
     * Public Requirements:
     * - The caller must be the owner of the contract.
     */
    function setPrizePoolImplementation(
        address _prizePoolImplementation
    ) 
        public
        onlyOwner()
    {
        _setPrizePoolImplementation(_prizePoolImplementation);
    }


    /**
     * See {JackpotComptroller._openJackpot}.
     */
    function openJackpot(
          JL.JackpotConstantSchema calldata _constants
        , JL.JackpotQualifierSchema[] calldata _qualifiers
        , JL.CollateralSchema[] calldata _collateral
    ) 
        public
        payable
        returns ( 
            address
        )
    { 
        require(
              _constants.cancelTime > int256(block.timestamp).toInt()
            , "Jackpot::openJackpot: cancel time must be in the future."
        );

        require(
              _constants.endTime > int256(block.timestamp).toInt()
            , "Jackpot::openJackpot: end time must be in the future."   
        );

        require(
              msg.value > 0 || _collateral.length > 0
            , "Jackpot::openJackpot: collateral must be provided."
        );

        // require(
        //     msg.value >= _constants.startingCollateral
        //     , "Jackpot::openJackpot: insufficient collateral."
        // );

        return _openJackpot(
              _constants
            , _qualifiers
            , _collateral
        ); 
    }
}
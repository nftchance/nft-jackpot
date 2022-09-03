// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import { IJackpotPrizePool } from "./interfaces/IJackpotPrizePool.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { JackpotGreeks } from "../JackpotGreeks.sol";

import { JackpotLibrary as JL } from "../Library/JackpotLibrary.sol"; 

contract JackpotPrizePool is 
      IJackpotPrizePool
    , Initializable
    , JackpotGreeks
{
    address public seeder;
    address public comptroller;

    mapping(string => uint256) public tokenFingerprints;

    JL.JackpotConstantSchema public constants;
    JL.JackpotQualifierSchema[] public qualifiers;
    JL.CollateralSchema[] public collateral;

    JL.JackpotEntrySchema[] entries;

    event JackpotCollateralized(JL.CollateralSchema[] collateral);
    event JackpotEntryAdded(JL.JackpotEntrySchema entry);

    constructor() {
        /// @dev Initialize the pool with the seeded collateral.
    }

    modifier onlySeeder() {
        /// @dev Only the seeder can call this function.
        require(
              msg.sender == seeder
            , "JackpotPrizePool: onlySeeder"
        );
        _; 
    }

    modifier onlyComptroller() { 
        /// @dev Only the comptroller can call this function.
        require(msg.sender == comptroller);
        _;
    }

    function initialize(
          address _seeder        
        , address _comptroller
        , JL.JackpotConstantSchema calldata _constants
        , JL.JackpotQualifierSchema[] calldata _qualifiers
        , JL.CollateralSchema[] calldata _collateral
    ) 
        public 
        initializer 
    {
        /// @dev Initialize Prize Pool access permissions.
        seeder = _seeder;
        comptroller = _comptroller;

        /// @dev Initializing the controlling variables of the pool.
        constants = _constants;
        qualifiers = _qualifiers;

        /// @dev Initialize the pool with the seeded collateral.
        fundJackpot(_collateral); 
    }

    function fundJackpot(
        JL.CollateralSchema[] calldata _collateral
    ) 
        public 
        override 
        onlySeeder() 
    {
        /// @dev Add the collateral to the pool.
        // TODO: Implement collateralization logic.

        /// @dev Emit the collateralized event.
        emit JackpotCollateralized(_collateral);
    }

    function abortJackport() 
        public 
        override
        onlySeeder() 
    { 
        constants.cancelTime = int256(block.timestamp).fromInt();
    }

    function _openEntry(
          bytes32 _fingerprint
        , uint256 _quantity
    ) 
        internal 
    {

    }

    function openEntryEmpty() public {}

    function openEntryBacked() public {}

    function openEntrySignature() public {}

    function terminateJackpot() public {}

    function drawJackpot() public {}

    function claimJackpot() public {}

    function claimRefund() public {}
}
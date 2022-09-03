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


    JL.JackpotSchema public schema;

    JL.JackpotConstantSchema public constants;
    JL.JackpotQualifierSchema[] public qualifiers;
    JL.CollateralSchema[] public collateral;

    JL.JackpotEntrySchema[] entries;

    mapping(string => uint256) public tokenFingerprints;

    event JackpotCollateralized(JL.CollateralSchema[] collateral);
    event JackpotEntryAdded(JL.JackpotEntrySchema entry);

    modifier onlySeeder() {
        /// @dev Only the seeder can call this function.
        require(
              msg.sender == seeder
            , "JackpotPrizePool: onlySeeder"
        );
        terminateJackpot();
        
        _; 
    }

    modifier onlyComptroller() { 
        /// @dev Only the comptroller can call this function.
        require(msg.sender == comptroller);
        _;
    }

    modifier onlySeeded() {
        /// @dev Only the seeder can call this function.
        require(
              schema.status == JL.STATUS.SEEDED 
            , "JackpotPrizePool::onlySeeded: Jackpot is in a state besides SEEDED."
        );
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
        onlySeeded()
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
        onlySeeded()
    { 
        /// @dev Update the state of the Jackpot to aborted.
        schema.status = JL.STATUS.ABORTED;

        /// @dev Transfer all the collateral back to the seeder.
        // TODO: Implement the code for this
    }

    function _openEntry(
          bytes32 _fingerprint
        , uint256 _quantity
    ) 
        internal 
    {

    }

    function openEntryEmpty() 
        public
        onlySeeded() 
    {}

    function openEntryBacked() 
        public
        onlySeeded() 
    {}

    function openEntrySignature() 
        public
        onlySeeded() 
    {}

    function _drawJackpot()
        internal
        returns (
            bytes32 requestId
        )
    {
        /// @dev Update the state of the Jackpot to drawing.
        schema.status = JL.STATUS.DRAWING;

        /// @dev Request a random number from Chainlink through the Comptroller.
        return IComptroller(comptroller).drawJackpot();
    }

    function drawJackpot() 
        override 
        public
        onlySeeded()
        returns (
            bytes32 requestId
        )
    {
        /// @dev Confirm the end time of entry purchasing has passed which forcefully
        ///      keeps the Prize Pool moving forward. Once the endTime has passed,
        ///      the Jackpot will be drawn and it cannot be stopped.
        require(
              constants.endTime <= int256(block.timestamp).toInt()
            , "JackpotPrizePool::drawJackpot: entry period not over."  
        );

        /// @dev Confirm that the jackpot has not been canceled nor expired.
        ///      cancelled == forcefully aborted
        ///      expired == 'reserve' was not met while time < cancelTime
        /// TODO: Implement this code

        /// @dev Send the request for randomness and return the requestId.
        return _drawJackpot();
    }

    function terminateJackpot() 
        public
        onlySeeder() 
        onlySeeded()
    {
        // TODO: Confirm minimum funding has been reached.

        return _drawJackpot();
    }

    function processJackpot(
        uint256[] calldata _randomWords
    )
        public 
        override 
        onlyComptroller() 
    {
        /// @dev Set the status of the Jackpot to completed.
        schema.status = JL.STATUS.ENDED;

        /// @dev Save the winning entry indexes to the record!
        schema.winners = _randomWords;
    }

    function claimJackpot(
        uint256 _entryId
    ) 
        public 
    {
        /// @dev Confirm the Jackpot has been completed.
        require(
              schema.status == JL.STATUS.ENDED
            , "JackpotPrizePool::claimJackpot: Jackpot process has not ended."
        );

        /// @dev Confirm the user has a winning entry.
        require(
              entries[_entryId].buyer == msg.sender
            , "JackpotPrizePool::claimJackpot: User does not have a winning entry."
        );

        /// @dev Transfer the collateral that this entry won to the user.
        // TODO: Implement the code here
    }

    function claimRefund(
        uint256 _entryId
    ) 
        public 
    {
        require (
              schema.status == JL.STATUS.ABORTED
            , "JackpotPrizePool::claimRefund: Jackpot has not been aborted."
        );

        require (
              msg.sender == entries[_entryId].buyer
            , "JackpotPrizePool::claimRefund: Caller is not the buyer of this entry."
        );

        /// @dev Determine the amount of eth to refund for this entry.
        uint256 owed = _getPrice(entries[_entryId].quantity);

        /// @dev Clear out the quantity of entries to prevent re-entrancy.
        delete entries[_entryId].quantity;

        /// @dev Refund the amount of eth that the user has deposited.
        (bool success, ) = msg.sender.call{value: owed}("");
    }
}
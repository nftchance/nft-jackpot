// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import { JackpotPrizePoolInterface } from "./interfaces/JackpotPrizePoolInterface.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { JackpotGreeks } from "../Comptroller/JackpotGreeks.sol";
import { JackpotFingerprint } from "../Comptroller/JackpotFingerprint.sol";
import { JackpotComptrollerInterface } from "../Comptroller/interfaces/JackpotComptrollerInterface.sol";

import { JackpotLibrary as JL } from "../Library/JackpotLibrary.sol"; 

import { PRBMathSD59x18 } from "@prb/math/contracts/PRBMathSD59x18.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract JackpotPrizePool is 
      JackpotPrizePoolInterface
    , Initializable
    , JackpotGreeks
    , JackpotFingerprint
{
    using PRBMathSD59x18 for int256;

    address public seeder;
    address public comptroller;

    JL.JackpotSchema public schema;

    JL.JackpotConstantSchema public constants;
    JL.JackpotQualifierSchema[] public qualifiers;
    JL.CollateralSchema[] public collateral;

    JL.JackpotEntrySchema[] entries;

    event JackpotCollateralized(JL.CollateralSchema[] collateral);
    event JackpotEntryAdded(JL.JackpotEntrySchema entry);

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
        require(
              msg.sender == comptroller
            , "Jackpot::onlyComptroller: function can only be called by comptroller"
        );
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
        , JL.JackpotConstantSchema memory _constants
        , JL.JackpotQualifierSchema[] memory _qualifiers
        , JL.CollateralSchema[] memory _collateral
    ) 
        public 
        payable
        initializer 
    {
        require(
              seeder == address(0)
            , "JackpotPrizePool::initialize: prize pool is already seeded."
        );

        /// @dev Initialize Prize Pool access permissions.
        seeder = _seeder;
        comptroller = _comptroller;

        /// @dev Initializing the controlling variables of the pool.
        constants = _constants;
        
        for (uint256 i = 0; i < _qualifiers.length; i++) {
            qualifiers.push(_qualifiers[i]);
        }

        /// @dev Initialize the pool with the seeded collateral.
        _fundJackpot(_collateral); 
    }

    function _fundJackpot(
        JL.CollateralSchema[] memory _collateral
    ) 
        internal 
    {
        /// @dev Add the collateral to the pool.
        for (uint256 i = 0; i < _collateral.length; i++) {
            /// @dev Transfer the collateral to the pool.
            IERC721(_collateral[i].token).safeTransferFrom(
                  msg.sender
                , address(this)
                , _collateral[i].id
            );

            collateral.push(_collateral[i]);
        }

        /// @dev Emit the event that the pool has been collateralized.
        emit JackpotCollateralized(_collateral);
    }

    function fundJackpot(
        JL.CollateralSchema[] calldata _collateral
    ) 
        override 
        external 
        virtual
        onlySeeder() 
        onlySeeded()
    {
        _fundJackpot(_collateral);
    }

    function abortJackpot() 
        override
        external
        virtual 
        onlySeeder() 
        onlySeeded()
    { 
        /// @dev Update the state of the Jackpot to aborted.
        schema.status = JL.STATUS.ABORTED;

        /// @dev Transfer all the collateral back to the seeder.
        for(
            uint256 i = 0;
            i < collateral.length;
            i++
        ) {
            JL.CollateralSchema memory collateralSchema = collateral[i];

            /// @dev Transfer the collateral back to the seeder.
            // TODO: For now we are assume that we are only handling ERC721s.
            IERC721(collateralSchema.token).safeTransferFrom(
                  address(this)
                , seeder
                , collateralSchema.id
            );
        }
    }

    function _openEntry(
          bytes32 _fingerprint
        , uint256 _quantity
    ) 
        internal 
        onlySeeded()
        onlyVirginFingerprint(_fingerprint)
    {
        uint256 price = _getPrice(_quantity);

        /// @dev Confirm the minimum amount of funding for quanity was provided
        ///      as there will be "price slippage" in ramps.
        require(
              msg.value >= price
            , "JackpotPrizePool::_openEntry: The amount sent does not match the price." 
        );
        
        /// @dev Get the closing index of the last token in the 
        ///      pool if there is already an entry.
        uint256 tail = _quantity;
        if(entries.length > 0) {
            tail += entries[entries.length - 1].tail;
        }

        /// @dev Add the entry to the entries array.
        entries.push(
            JL.JackpotEntrySchema({
                  buyer: msg.sender
                , quantity: _quantity
                , value: price
                , tail: tail
            })
        );

        /// @dev Determine how much the buyer overpaid by.
        uint256 refund = msg.value - price;

        /// @dev Inline refund the buyer (no waiting or "i didnt get my refund").
        (bool sent, ) = msg.sender.call{value: refund}("");
        
        /// @dev Proof the buyer received their refund without fail.
        require(
              sent
            , "JackpotPrizePool::_openEntry: Failed to send refund."
        );

        /// @dev Emit the entry added event.
        emit JackpotEntryAdded(entries[entries.length - 1]);
    }

    /**
     * @notice Allows a buyer to open an entry into the Jackpot.
     * @param _quantity The amount of tickets to buy.

     * 
     * Requirements:
     * - The Jackpot must not have any qualifiers.
     */
    function openEntryEmpty(
        uint256 _quantity
    ) 
        public
        payable
    {
        /// @dev Confirm that this whitelist is open entry.
        require(
              qualifiers.length == 0
            , "JackpotPrizePool::openEntryEmpty: This Jackpot has qualifiers."
        );

        /// @dev Create the entry using the wallet address as the fingerprint.
        _openEntry(
              bytes32(abi.encode(msg.sender))
            , _quantity
        );
    }

    function openEntryBacked(
        JL.CollateralSchema[] calldata _collateral
    ) 
        public
        payable
        onlySeeded() 
    { }

    function openEntrySignature() 
        public
        payable
        onlySeeded() 
    { }

    function _drawJackpot()
        internal
        returns (
            uint256 requestId
        )
    {
        /// @dev Update the state of the Jackpot to drawing.
        schema.status = JL.STATUS.DRAWING;

        /// @dev Request a random number from Chainlink through the Comptroller.
        return JackpotComptrollerInterface(comptroller).drawJackpot(
            uint32(
                entries[entries.length - 1].tail
            )
        );
    }

    function drawJackpot() 
        override 
        external
        virtual
        onlySeeded()
        returns (
            uint256 requestId
        )
    {
        /// @dev Confirm the end time of entry purchasing has passed which forcefully
        ///      keeps the Prize Pool moving forward. Once the endTime has passed,
        ///      the Jackpot will be drawn and it cannot be stopped.
        require(
              constants.endTime <= int256(block.timestamp).toInt()
            , "JackpotPrizePool::drawJackpot: entry period not over."  
        );

        /// @dev Confirm that the jackpot has not expired due to not meeting the reserve
        ///      of funds needed for the Jackpot to draw.
        /// TODO: Implement this code

        /// @dev Send the request for randomness and return the requestId.
        return _drawJackpot();
    }

    function terminateJackpot() 
        public
        onlySeeder() 
        onlySeeded()
        returns (
            uint256 requestId
        )
    {
        // TODO: Confirm minimum funding has been reached.

        requestId = _drawJackpot();
    }

    function processJackpot(
        uint256[] calldata _randomWords
    )
        override 
        public 
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
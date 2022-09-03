// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import { JackpotGreeks } from "./JackpotGreeks.sol";
import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { VRFConsumerBase } from "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

import { IJackpotPrizePool } from "./PrizePool/interfaces/IJackpotPrizePool.sol";

contract JackpotComptroller is
      JackpotGreeks
    , VRFConsumerBase 
{
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

    function _depositCollateral(
        CollateralSchema[] memory _collateral
    ) 
        public
        onlyComptroller() 
    {
        /// @dev Emit single event for all tokens being deposited.
        /// @notice This is not an issue to be done first since if the tx 
        ///         reverts and takes the event with it.
        emit JackpotCollateralized(_collateral);

        for(uint i; i < _collateral.length; i++) {
            CollateralSchema memory collateralToken = _collateral[i];

            /// @dev Make sure the caller owns the token being deposited.
            /// @notice The ownership check is handled at this base level to avoid
            ///         the need for multiple for loops / losing non-fungible ability.
            IERC721 token = IERC721(collateralToken.token);
            require(
                token.ownerOf(collateralToken.id) == msg.sender,
                "Jackpot: not owner."
            );

            /// @dev Always append newly deposited collateral to end of roster.
            collateral.push(_collateral[i]);

            /// @dev Deposit the collateral into this Prize Pool.
            token.transferFrom(
                  msg.sender
                , address(this)
                , collateralToken.id
            );
        }
    }

    function _buyEntry(
          address _buyer
        , uint256 _quantity
    )
        public
        payable
        onlyComptroller()
        returns (uint256 tail)
    {
        tail = _quantity;

        if(entries.length > 0) tail += entries[entries.length - 1].tail;

        JackpotEntrySchema memory entry = JackpotEntrySchema({
            buyer: _buyer,
            quantity: _quantity,
            tail: tail
        });

        emit JackpotEntryAdded(entry);
    }

    function _exitCollateral(
        address[] receivers
    ) 
        public
        payable
        onlyComptroller()
    { 
        for(
            uint i; 
            i < receivers.length;
            i++
        ) { 
            address receiver = receivers[i];
            CollateralSchema memory collateralToken = collateral[i];

            IERC721 token = IERC721(collateralToken.token);
            token.transferFrom(
                  address(this)
                , receiver
                , collateralToken.id
            );
        }

        RaffleStruct storage raffle = raffles[_raffleId];
        // Only when the raffle has been asked to be closed and the platform
        require(
            raffle.status == STATUS.EARLY_CASHOUT ||
                raffle.status == STATUS.CLOSING_REQUESTED,
            "Raffle in wrong status"
        );

        raffle.randomNumber = _normalizedRandomNumber;
        raffle.winner = raffle.entries[_normalizedRandomNumber];
        raffle.status = STATUS.ENDED;

        IERC721 _asset = IERC721(raffle.collateralAddress);
        _asset.transferFrom(
            address(this),
            raffle.entries[_normalizedRandomNumber],
            raffle.collateralId
        );

        (bool sent, ) = raffle.seller.call{value: address(this).balance}("");
        require(sent, "Failed to send Ether");
    }

    // can be called by the seller at every moment once enough funds has been raised
    /// @param _raffleId Id of the raffle
    /// @notice the seller of the nft, if the minimum amount has been reached, can call an early cashout, finishing the raffle
    /// @dev it triggers Chainlink VRF1 consumer, and generates a random number that is normalized and checked that corresponds to a MW player
    function earlyCashOut(uint256 _raffleId) external {
        RaffleStruct storage raffle = raffles[_raffleId];
        FundingStructure memory funding = fundingList[_raffleId];

        require(raffle.seller == msg.sender, "Not the seller");
        // Check if the raffle is already accepted
        require(
            raffle.status == STATUS.ACCEPTED,
            "Raffle not in accepted status"
        );
        require(
            raffle.amountRaised >= funding.minimumFundsInWeis,
            "Not enough funds raised"
        );

        raffle.status = STATUS.EARLY_CASHOUT;

        //    IVRFConsumerv1 randomNumber = IVRFConsumerv1(chainlinkContractAddress);
        getRandomNumber(_raffleId, raffle.entries.length);

        emit EarlyCashoutTriggered(_raffleId, raffle.amountRaised);
    }

    // helper method to get the winner address of a raffle
    /// @param _raffleId Id of the raffle
    /// @param _normalizedRandomNumber index of the array that contains the winner of the raffle. Generated by chainlink
    /// @return the wallet that won the raffle (at the moment, as must be confirmed that is a member of the MW community)
    function getWinnerAddressFromRandom(
        uint256 _raffleId,
        uint256 _normalizedRandomNumber
    ) external view returns (address) {
        return raffles[_raffleId].entries[_normalizedRandomNumber];
    }

    /// @param _raffleId Id of the raffle
    /// @notice the operator finish the raffle, if the desired funds has been reached
    /// @dev it triggers Chainlink VRF1 consumer, and generates a random number that is normalized and checked that corresponds to a MW player
    function setWinner(uint256 _raffleId)
        external
        payable
        nonReentrant
        onlyRole(OPERATOR_ROLE)
    {
        RaffleStruct storage raffle = raffles[_raffleId];
        FundingStructure storage funding = fundingList[_raffleId];
        // Check if the raffle is already accepted or is called again because early cashout failed
        require(
            raffle.status == STATUS.ACCEPTED, //||
            "Raffle in wrong status"
        );
        require(
            raffle.amountRaised >= funding.minimumFundsInWeis,
            "Not enough funds raised"
        );

        //   if (raffle.status != STATUS.EARLY_CASHOUT) {
        require(
            funding.desiredFundsInWeis <= raffle.amountRaised,
            "Desired funds not raised"
        );
        raffle.status = STATUS.CLOSING_REQUESTED;
        // }

        //   IVRFConsumerv1 randomNumber = IVRFConsumerv1(chainlinkContractAddress);
        getRandomNumber(_raffleId, raffle.entries.length);

        emit SetWinnerTriggered(_raffleId, raffle.amountRaised);
    }

        /// @param _raffleId Id of the raffle
    /// @dev The operator can cancel the raffle. The NFT is sent back to the seller
    /// The raised funds are send to the destination wallet. The buyers will
    /// be refunded offchain in the metawin wallet
    function cancelRaffle(uint256 _raffleId)
        external
        nonReentrant
        onlyRole(OPERATOR_ROLE)
    {
        RaffleStruct storage raffle = raffles[_raffleId];
        //FundingStructure memory funding = fundingList[_raffleId];
        // Dont cancel twice, or cancel an already ended raffle
        require(
            raffle.status != STATUS.ENDED &&
                raffle.status != STATUS.CANCELLED &&
                raffle.status != STATUS.EARLY_CASHOUT &&
                raffle.status != STATUS.CLOSING_REQUESTED &&
                raffle.status != STATUS.CANCEL_REQUESTED,
            "Wrong status"
        );

        // only if the raffle is in accepted status the NFT is staked and could have entries sold
        if (raffle.status == STATUS.ACCEPTED) {
            // transfer nft to the owner
            IERC721 _asset = IERC721(raffle.collateralAddress);
            _asset.transferFrom(
                address(this),
                raffle.seller,
                raffle.collateralId
            );
        }
        raffle.status = STATUS.CANCEL_REQUESTED;
        raffle.cancellingDate = block.timestamp;

        emit RaffleCancelled(_raffleId, raffle.amountRaised);
    }

    /// @param _raffleId Id of the raffle
    /// @dev The player can claim a refund during the first 30 days after the raffle was cancelled
    /// in the map "ClaimsData" it is saves how much the player spent on that raffle, as they could
    /// have bought several entries
    function claimRefund(uint256 _raffleId) external nonReentrant {
        RaffleStruct storage raffle = raffles[_raffleId];
        require(raffle.status == STATUS.CANCEL_REQUESTED, "wrong status");
        require(
            block.timestamp <= raffle.cancellingDate + 30 days,
            "claim time expired"
        );

        ClaimStruct storage claimData = claimsData[
            keccak256(abi.encode(msg.sender, _raffleId))
        ];

        require(claimData.claimed == false, "already refunded");

        raffle.amountRaised = raffle.amountRaised - claimData.amountSpentInWeis;

        claimData.claimed = true;
        (bool sent, ) = msg.sender.call{value: claimData.amountSpentInWeis}("");
        require(sent, "Fail send refund");

        emit Refund(_raffleId, claimData.amountSpentInWeis, msg.sender);
    }

    /// @param _raffleId Id of the raffle
    /// @dev after 30 days after cancelling passes, the operator can transfer to
    /// destinationWallet the remaining funds
    function transferRemainingFunds(uint256 _raffleId)
        external
        nonReentrant
        onlyRole(OPERATOR_ROLE)
    {
        RaffleStruct storage raffle = raffles[_raffleId];
        require(raffle.status == STATUS.CANCEL_REQUESTED, "Wrong status");
        require(
            block.timestamp > raffle.cancellingDate + 30 days,
            "claim too soon"
        );

        raffle.status = STATUS.CANCELLED;

        (bool sent, ) = destinationWallet.call{value: raffle.amountRaised}("");
        require(sent, "Fail send Eth to MW");

        emit RemainingFundsTransferred(_raffleId, raffle.amountRaised);

        raffle.amountRaised = 0;
    }

    // TODO THE BREAK BETWEEN TWO VERSIONS OF THE PRIZE POOL
    
    function _abortJackpot(
        uint256 _jackpotId
    ) 
        internal 
    { 
        // Confirm the Jackpot is open.
        // Confirm the sender is the seeder.
        // Mark Jackpot as aborted.
        // Withdraw all collateral.
    }

    function _fundJackpot(
          uint256 _jackpotId
        , CollateralSchema[] calldata _collaterals
    ) 
        internal 
    { 
        // Confirm that the jackpot can be funded.
        // Confirm that the jackpot has not already been drawn.
    }

    function _openEntry(
        bytes calldata _fingerprint
    )
        internal
        payable
    { 
        // Verify that the fingerprint decay is at zero.
        // Confirm the message value is sufficient to cover quantity.
    }

    function _openEntryEmpty(
          uint256 _jackpotId
    ) 
        internal
        payable
    { 
        // Confirm that the Jackpot is open.
        // Use wallet address as fingerprint.
    }

    function _openEntryBacked(
        uint256 _jackpotId
        , CollateralSchema[] calldata _collaterals
    ) 
        internal
        payable 
    { 
        // Confirm that the jackpot is open.
        // Confirm that the collateral meets the qualifiers set.
        // If more than one qualifier is required, then while loop until meeting the 
        // requirements of all qualifiers otherwise revert.
        // Confirm that the collateral fingerprint decay is at 0.
            // Proceed with normal entry opening however we cannot use the _openEntry
            // as everything will have to be done inline in this function to avoid an extra for loop.
        // Confirm the message value is sufficient to cover quantity.
    }

    function _openEntrySignature(
          uint256 _jackpotId
        , bytes calldata _signature
    ) 
        internal
        payable 
    { 
        // Confirm that the Jackpot is open.
        // Confirm that the signature is valid.
        // Proceed with normal entry opening.
    }

    function _drawJackpot(
        uint256 _jackpotId
    ) 
        internal 
    { 
        // Confirm that the jackpot is ready to be drawn
        // Confirm that the jackpot is not already drawn
        // Confirm that the jackpot is not already aborted
        // Use Chainlink to get the winner.
        // Store chainlink request ID in mapping pointing to Jackpot.
    }

    function _terminateJackpot(
        uint256 _jackpotId
    ) 
        internal 
    { 
        // Confirm that the sender is the seeder of the jackpot.
        // Confirm that the jackpot is in the open state.
        // Set the state to choosing winner.
        // Use Chainlink to get the winner.
        // Store chainlink request ID in mapping pointing to Jackpot.
    }

    function _claimJackpot(
          uint256 _jackpotId
        , uint256 _entryId
    ) 
        internal 
    { 
        // Confirm that the sender is the owner of the entry.
        // Confirm that the entry is the winner.
        // Transfer the prize associated to this entry id to the sender.
    }

    function _claimRefund(
          uint256 _jackpotId
        , uint256 _entryId
    ) 
        internal 
    { 
        // Confirm that the sender is the owner of the entry.
        // Determine how much of a refund is owed for this entry.
        // Transfer the refund to the entry owner.
    }
}

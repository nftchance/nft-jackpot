// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

import "./JackpotGreeks.sol";

contract JackpotComptroller is
      JackpotGreeks
    , VRFConsumerBase 
{

    bytes32 internal keyHash; // chainlink
    uint256 internal fee; // fee paid in LINK to chainlink. (0.1 in Rinkeby, 2 in Mainnet)

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
        require(_coordinator != address(0));
        require(_linkToken != address(0));
        require(_keyHash != bytes32(0));
        require(_fee != 0);

        keyHash = _keyHash;
        fee = _fee;
    }

    function _createNewJackpot(
          JackpotConstantSchema _constants
        , JackpotQualifierSchema[] calldata _qualifiers
        , uint256 _cancelTime
    )
        internal
        payable
        returns (uint256)
    {
        uint256 jackpotId = jackpots.length; 

        // TODO: Implement the Clone deployment
        // address prizePoolAddress = determineAddress(jackpotId);
        // address prizePool = new address(prizePoolAddress);

        /// @dev Save the Jackpot to the record. 
        jackpots[jackpotId] = JackpotSchema({
              status: STATUS.CREATED
            , constants: _constants
            , qualifiers: _qualifiers
            , prizePool: prizePoolAddress
            , winner: 0
            , cancelTime: _cancelTime
        });

        /// @dev Announce to the world!
        emit JackpotCreated(msg.sender, jackpotId);

        return jackpotId; 
    }


    /// @dev callable by players. Depending on the number of entries assigned to the price structure the player buys (_id parameter)
    /// one or more entries will be assigned to the player.
    /// Also it is checked the maximum number of entries per user is not reached
    /// As the method is payable, in msg.value there will be the amount paid by the user
    /// @notice If the operator made a call to set a required nft, only the owners of that nft can make a call to this method. This will be
    /// used for special raffles
    /// @param _raffleId: id of the raffle
    /// @param _id: id of the price structure
    function buyEntry(uint256 _raffleId, uint256 _id)
        external
        payable
    {
        // TODO: Verify that one of the qualifiers has been met for the raffle.

        if (raffles[_raffleId].requiredNFT != address(0)) {
            IERC721 requiredNFT = IERC721(raffles[_raffleId].requiredNFT);
            require(requiredNFT.balanceOf(msg.sender) > 0, "No NFT");
        }
        require(
            raffles[_raffleId].status == STATUS.ACCEPTED,
            "Raffle is not in accepted"
        ); // 1808
        PriceStructure memory priceStruct = getPriceStructForId(_raffleId, _id);
        //  require(priceStruct.price > 0, "id not supported");
        require(
            msg.value == priceStruct.price,
            "msg.value must be equal to the price"
        ); // 1722

        bytes32 hash = keccak256(abi.encode(msg.sender, _raffleId));
        // check there are enough entries left for this particular user
        require(
            claimsData[hash].numEntriesPerUser + priceStruct.numEntries <=
                raffles[_raffleId].maxEntries,
            "Bought too many entries"
        ); // 3425

        address entry = msg.sender; // 12
        for (uint256 i = 0; i < priceStruct.numEntries; i++) {
            raffles[_raffleId].entries.push(entry);
        }
        raffles[_raffleId].amountRaised += msg.value; // 6917 gas
        // update the field entriesLength, used in frontend to avoid making extra calls
        raffles[_raffleId].entriesLength = raffles[_raffleId].entries.length;
        //update claim data
        claimsData[hash].numEntriesPerUser += priceStruct.numEntries;
        claimsData[hash].amountSpentInWeis += msg.value;

        emit EntrySold(
            _raffleId,
            msg.sender,
            raffles[_raffleId].entries.length,
            _id
        ); // 2377
    }


    // The operator can call this method once they receive the event "RandomNumberCreated"
    // triggered by the VRF v1 consumer contract (RandomNumber.sol)
    /// @param _raffleId Id of the raffle
    /// @param _normalizedRandomNumber index of the array that contains the winner of the raffle. Generated by chainlink
    /// @notice it is the method that sets the winner and transfers funds and nft
    /// @dev called only after the backekd checks the winner is a member of MW. Only those who bought using the MW site
    /// can be winners, not those who made the call to "buyEntries" directly without using MW
    function transferNFTAndFunds(
        uint256 _raffleId,
        uint256 _normalizedRandomNumber
    ) internal nonReentrant {
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
        ); // transfer the tokens to the contract

        uint256 amountForPlatform = (raffle.amountRaised *
            raffle.platformPercentage) / 10000;
        uint256 amountForSeller = raffle.amountRaised - amountForPlatform;
        // transfer amount (75%) to the seller.
        (bool sent, ) = raffle.seller.call{value: amountForSeller}("");
        require(sent, "Failed to send Ether");
        // transfer the amount to the platform
        (bool sent2, ) = destinationWallet.call{value: amountForPlatform}("");
        require(sent2, "Failed send Eth to MW");
        emit FeeTransferredToPlatform(_raffleId, amountForPlatform);

        emit RaffleEnded(
            _raffleId,
            raffle.entries[_normalizedRandomNumber],
            raffle.amountRaised,
            _normalizedRandomNumber
        );
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


    /// @dev this is the method that will be called by the smart contract to get a random number
    /// @param _id Id of the raffle
    /// @param _entriesSize length of the entries array of that raffle
    /// @return requestId Id generated by chainlink
    function getRandomNumber(uint256 _id, uint256 _entriesSize)
        internal
        returns (bytes32 requestId)
    {
        // require(
        //     LINK.balanceOf(address(this)) > fee,
        //     "Not enough LINK - fill contract with faucet"
        // );
        // bytes32 result = requestRandomness(keyHash, fee);
        // // result is the requestId generated by chainlink. It is saved in a map linked to the param id
        // // chainlinkRaffleInfo[result] = RaffleInfo({id: _id, size: _entriesSize});
        // return result;
    }

    /// @dev Callback function used by VRF Coordinator. Is called by chainlink
    /// the random number generated is normalized to the size of the entries array, and an event is
    /// generated, that will be listened by the platform backend to be checked if corresponds to a
    /// member of the MW community, and if true will call transferNFTAndFunds
    /// @param requestId id generated previously (on method getRandomNumber by chainlink)
    /// @param randomness random number (huge) generated by chainlink
    function fulfillRandomness(bytes32 requestId, uint256 randomness)
        internal
        override
    {
        // randomness is the actual random number. Now extract from the aux map the original param id of the call
        // RaffleInfo memory raffleInfo = chainlinkRaffleInfo[requestId];
        // save the random number on the map with the original id as key
        // uint256 normalizedRandomNumber = randomness % raffleInfo.size;
        // RandomResult memory result = RandomResult({
        //     randomNumber: randomness,
        //     nomalizedRandomNumber: normalizedRandomNumber
        // });
        // requests[raffleInfo.id] = result;
        // // send the event with the original id and the random number
        // emit RandomNumberCreated(
        //     raffleInfo.id,
        //     randomness,
        //     normalizedRandomNumber
        // );
        // transferNFTAndFunds(raffleInfo.id, normalizedRandomNumber);
    }
}

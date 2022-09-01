// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract JackpotPrizePool {
    address public comptroller;

    struct CollateralSchema {
        address token; 
        uint256 id;
    }

    struct JackpotEntrySchema {
        address buyer; 
        uint256 quantity;
        uint256 tail;
    }

    mapping(string => uint256) public tokenFingerprints;

    CollateralSchema[] public collateral;

    JackpotEntrySchema[] entries;

    event JackpotCollateralized(CollateralSchema[] collateral);
    event JackpotEntryAdded(JackpotEntrySchema entry);

    constructor(
        CollateralSchema[] memory _collateral
    ) {
        /// @dev Initialize the pool with the seeded collateral.
        _depositCollateral(_collateral);
    }

    modifier onlyComptroller() { 
        /// @dev Only the comptroller can call this function.
        require(msg.sender == comptroller);
        _;
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

    /// @param _raffleId Id of the raffle
    /// @return array of entries of that particular raffle
    function getEntries(uint256 _raffleId)
        external
        view
        returns (address[] memory)
    {
        return raffles[_raffleId].entries;
    }

    function getClaimData(uint256 _raffleId, address _player)
        external
        view
        returns (ClaimStruct memory)
    {
        return claimsData[keccak256(abi.encode(_player, _raffleId))];
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

/// TRUNCATING A LIST OF NUMBERS WITHOUT SORTING AND MAINTAING PROVABLE RANDOMNESS

/// 15, 10, 5, 1, 25    -- 56    
/// 15 5, 1, 25         -- 46

/// the tail decreased by 10 however the random number is still the same

/// the reason things seem hard right now is because i am misuing random numbers?
/// if i want to do it like this, one would have to use some fucked up bubble sort?

    


















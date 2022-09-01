// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract JackpotPrizePool {
    address public comptroller;

    struct CollateralSchema {
        address token; 
        uint256 id;
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
}
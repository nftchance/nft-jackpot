// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

/**
 * @title Jackpot
 * @dev A contract that allows for the creation of a jackpot.
 */

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./JackpotComptroller.sol";

contract Jackpot is
    JackpotComptroller
{
    constructor(
          address _coordinator
        , address _linkToken
        , bytes32 _keyHash
        , uint256 _fee
    ) 
        JackpotComptroller(
              _coordinator
            , _linkToken
            , _keyHash
            , _fee
        )
    { }

    function getJackpot(uint256 _jackpotId)
        public
        view
        returns (JackpotSchema jackpotSchema)
    {
        jackpots = jackpots[_jackpotId];
    }

    function getJackpot() public { }

    function getEntry() public { }

    function openJackpot() public payable { }

    function abortJackpot() public { }

    function fundJackpot() public payable { }

    function openEntry() public { }

    function abortEntry() public { }

    function drawJackpot() public { }

    function claimPrize() public { }

    function claimRefund() public { }
}
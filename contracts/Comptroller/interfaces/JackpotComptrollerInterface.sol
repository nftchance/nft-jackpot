// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

interface JackpotComptrollerInterface {
    function drawJackpot(
        uint32 _winners
    ) 
        external
        returns (
            uint256 requestId
        );
}
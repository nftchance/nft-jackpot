// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import {PRBMathSD59x18} from "@prb/math/contracts/PRBMathSD59x18.sol";

contract JackpotFingerprint {
    using PRBMathSD59x18 for int256;

    int256 public decayRate; 

    mapping(string => int256) public tokenFingerprints;

    modifier onlyViriginFingerprint(
        string memory _fingerprint
    ) { 
        require(
              _fingerprintDecay(_fingerprint) == 0
            , "JackpotFingerprint::onlyViriginFingerprint: Fingerprint has already been used."
        );
        _;
    }

    function _initializeFingerprints(
        int256 _decayRate
    )
        internal
    {
        // TODO: There is a bug that needs to be handled here with the real initialize
        decayRate = _decayRate;
    }

    function _setFingerprint(
        string memory _fingerprint
    )
        internal
    {
        tokenFingerprints[_fingerprint] = int256(block.timestamp).fromInt();
    }

    /**
     * @notice Returns the decay of a fingerprint.
     * @param _fingerprint The fingerprint to check.
     * @return decay The decay of the fingerprint.
     */
    function _fingerprintDecay(
        string memory _fingerprint
    )
        internal
        view
        returns (
            int256 decay
        )
    {
        decay = tokenFingerprints[_fingerprint].toInt();

        int256 timeSinceUsed = int256(block.timestamp).fromInt() - decay;
        if (timeSinceUsed > 86400) { 
            return decay = 0;
        }

        decay = 86400 - timeSinceUsed;
    }
}
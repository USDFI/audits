/**
 * @title Reentrancy Guard
 * @dev ReentrancyGuard.sol contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: MIT
 *
 **/

pragma solidity =0.8.17;

contract ReentrancyGuard {
    /// @dev counter to allow mutex lock with only one SSTORE operation
    uint256 private _guardCounter;

    constructor() {
        // The counter starts at one to prevent changing it from zero to a non-zero
        // value, which is a more expensive operation.
        _guardCounter = 1;
    }

    /**
     * @dev Prevents a contract from calling itself, directly or indirectly.
     * Calling a `nonReentrant` function from another `nonReentrant`
     * function is not supported. It is possible to prevent this from happening
     * by making the `nonReentrant` function external, and make it call a
     * `private` function that does the actual work.
     */
    modifier nonReentrant() {
        _guardCounter += 1;
        uint256 localCounter = _guardCounter;
        _;
        require(
            localCounter == _guardCounter,
            "ReentrancyGuard: reentrant call"
        );
    }
}

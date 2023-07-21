/**
 * @title Interface Bribe Factory
 * @dev IBribeFactory.sol contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 **/

pragma solidity =0.8.17;

interface IBribeFactory {
    function createBribe(address token0, address token1)
        external
        returns (address);
}

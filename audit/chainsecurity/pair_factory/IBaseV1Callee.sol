/**
 * @title Interface Base V1 Callee
 * @dev IBaseV1Callee.sol contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: MIT
 *
 **/

pragma solidity =0.8.17;

interface IBaseV1Callee {
    function hook(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external;
}

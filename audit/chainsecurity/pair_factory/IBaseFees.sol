/**
 * @title Interface Base Fees
 * @dev IBaseFees.sol contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: Business Source License 1.1
 *
 **/

pragma solidity =0.8.17;

interface IBaseFees {
    function protocolFee() external view returns (uint256);

    function usdfiMakerFee() external view returns (uint256);

    function lpOwnerFee() external view returns (uint256);

    function claimFeesFor(
        address recipient,
        uint256 amount0,
        uint256 amount1
    ) external returns (uint256 claimed0, uint256 claimed1);

    function setFeeAmount(
        uint256 protocolFee,
        uint256 usdfiMakerFee,
        uint256 lpOwnerFee
    ) external;
}

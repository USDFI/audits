/**
 * @title Interface Referrals
 * @dev IReferrals contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: Business Source License 1.1
 *
 **/

pragma solidity =0.8.17;

interface IReferrals {
    function getSponsor(address account) external view returns (address);

    function isMember(address user) external view returns (bool);

    function membersList(uint256 id) external view returns (address);
}

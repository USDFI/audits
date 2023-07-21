/**
 * @title Interface Protocol Governance
 * @dev IProtocolGovernance.sol contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: Business Source License 1.1
 *
 **/

pragma solidity =0.8.17;

interface IProtocolGovernance {
    function setGovernance(address governance) external;

    function acceptGovernance() external;

    function setAdminAndVoter(address admin, address voter) external;

    function setStableMiner(address stableMiner) external;

    function updateBaseReferrals(
        address referralsContract,
        uint256 baseReferralFee,
        address mainRefFeeReceiver
    ) external;

    function governance() external view returns (address);

    function pendingGovernance() external view returns (address);

    function admin() external view returns (address);

    function voter() external view returns (address);

    function stableMiner() external view returns (address);

    function baseReferralsContract() external view returns (address);

    function baseReferralFee() external view returns (uint256);

    function mainRefFeeReceiver() external view returns (address);
}

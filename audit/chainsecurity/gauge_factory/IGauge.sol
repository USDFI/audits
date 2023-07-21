/**
 * @title Interface Gauge
 * @dev IGauge.sol contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: Business Source License 1.1
 *
 **/

pragma solidity =0.8.17;

interface IGauge {
    function DURATION() external returns (uint256);

    function periodFinish() external returns (uint256);

    function rewardRate() external returns (uint256);

    function lastUpdateTime() external returns (uint256);

    function rewardPerTokenStored() external returns (uint256);

    function fees0() external returns (uint256);

    function fees1() external returns (uint256);

    function gaugeFactory() external returns (address);

    function referralContract() external returns (address);

    function whitelisted(address owner, address receiver)
        external
        returns (bool);

    function earnedRefs(address owner) external returns (uint256);

    function referralFee() external returns (uint256);

    function refLevelPercent(uint256 level) external returns (uint256);

    function userRewardPerTokenPaid(address owner) external returns (uint256);

    function rewards(address owner) external returns (uint256);

    function derivedSupply() external returns (uint256);

    function derivedBalances(address owner) external returns (uint256);

    function claimVotingFees()
        external
        returns (uint256 claimed0, uint256 claimed1);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function lastTimeRewardApplicable() external view returns (uint256);

    function rewardPerToken() external view returns (uint256);

    function derivedBalance(address account) external view returns (uint256);

    function kick(address account) external;

    function earned(address account) external view returns (uint256);

    function getRewardForDuration() external view returns (uint256);

    function deposit(uint256 amount) external;

    function depositFor(uint256 amount, address account) external;

    function withdraw(uint256 amount) external;

    function getReward() external;

    function getRewardForOwner(address owner) external;

    function getRewardForOwnerToOtherOwner(address owner, address receiver)
        external;

    function notifyRewardAmount(uint256 reward) external;

    function updateReferral(
        address referralsContract,
        uint256 referralFee,
        uint256[] memory refLevelPercent
    ) external;

    function setWhitelisted(address receiver, bool whitelist) external;
}

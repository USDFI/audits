/**
 * @title Interface Bribe
 * @dev IBribe.sol contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: Business Source License 1.1
 *
 **/

pragma solidity =0.8.17;

interface IBribe {
    function WEEK() external view returns (uint256);

    function firstBribeTimestamp() external view returns (uint256);

    function isRewardToken(address token) external view returns (bool);

    function rewardTokens(uint256 ID) external view returns (address);

    function gaugeFactory() external view returns (address);

    function bribeFactory() external view returns (address);

    function userTimestamp(address owner, address token)
        external
        view
        returns (uint256);

    function _totalSupply(uint256 timestamp) external view returns (uint256);

    function _balances(address owner, uint256 timestamp)
        external
        view
        returns (uint256);

    function referralFee() external view returns (uint256);

    function referralContract() external view returns (address);

    function refLevelPercent(uint256 level) external view returns (uint256);

    function earnedRefs(address owner, address token)
        external
        view
        returns (uint256);

    function whitelisted(address owner, address receiver)
        external
        view
        returns (bool);

    function userFirstDeposit(address owner) external view returns (uint256);

    function getEpoch() external view returns (uint256);

    function rewardsListLength() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function totalSupplyNextEpoch() external view returns (uint256);

    function totalSupplyAt(uint256 timestamp) external view returns (uint256);

    function balanceOfAt(address voter, uint256 timestamp)
        external
        view
        returns (uint256);

    function balanceOf(address voter) external view returns (uint256);

    function earned(address voter, address rewardToken)
        external
        view
        returns (uint256);

    function _earned(
        address voter,
        address rewardToken,
        uint256 timestamp
    ) external view returns (uint256);

    function rewardPerToken(address rewardsToken, uint256 timestmap)
        external
        view
        returns (uint256);

    function _deposit(uint256 amount, address voter) external;

    function _withdraw(uint256 amount, address voter) external;

    function notifyRewardAmount(address rewardsToken, uint256 reward) external;

    function getReward() external;

    function getRewardForOwner(address voter) external;

    function getRewardForOwnerToOtherOwner(address voter, address receiver)
        external;

    function getRewardForOwnerToOtherOwnerSingleToken(
        address voter,
        address receiver,
        address[] memory tokens
    ) external;

    function recoverERC20(address tokenAddress, uint256 tokenAmount) external;

    function addRewardtoken(address rewardsToken) external;

    function setWhitelisted(address receiver, bool whitlist) external;

    function updateReferral(
        address referralsContract,
        uint256 referralFee,
        uint256[] memory refLevelPercent
    ) external;
}

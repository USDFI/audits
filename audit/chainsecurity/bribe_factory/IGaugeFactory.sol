/**
 * @title Interface Gauge Factory
 * @dev IGaugeFactory.sol contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: Business Source License 1.1
 *
 **/

pragma solidity =0.8.17;

interface IGaugeFactory {
    function tokens() external view returns (address[] memory);

    function getGauge(address token) external view returns (address);

    function getBribes(address gauge) external view returns (address);

    function reset(address user) external;

    function poke(address owner) external;

    function vote(
        address user,
        address[] calldata tokenVote,
        uint256[] calldata weights
    ) external;

    function addGauge(address tokenLP, uint256 maxVotesToken)
        external
        returns (address);

    function deprecateGauge(address token) external;

    function resurrectGauge(address token) external;

    function length() external view returns (uint256);

    function distribute(uint256 start, uint256 end) external;

    function updateVeProxy(address veProxy) external;

    function updatePokeDelay(uint256 pokeDelay) external;

    function updateMaxVotesToken(uint256 ID, uint256 maxVotesToken) external;

    function updateReferrals(
        address gauge,
        address referralsContract,
        uint256 referralFee,
        uint256[] memory refLevelPercent
    ) external;

    function bribeFactory() external view returns (address);

    function totalWeight() external view returns (uint256);

    function delay() external view returns (uint256);

    function lastDistribute() external view returns (uint256);

    function lastVote(address user) external view returns (uint256);

    function nextPoke(address user) external view returns (uint256);

    function lockedTotalWeight() external view returns (uint256);

    function lockedBalance() external view returns (uint256);

    function locktime() external view returns (uint256);

    function epoch() external view returns (uint256);

    function lockedWeights(address user) external view returns (uint256);

    function maxVotesToken(address user) external view returns (uint256);

    function hasDistributed(address user) external view returns (bool);

    function _tokens(uint256 tokenID) external view returns (address);

    function gauges(address token) external view returns (address);

    function gaugeStatus(address token) external view returns (bool);

    function gaugeExists(address token) external view returns (bool);

    function pokeDelay() external view returns (uint256);

    function bribes(address gauge) external view returns (address);

    function weights(address token) external view returns (uint256);

    function votes(address user, address token) external view returns (uint256);

    function tokenVote(address user, uint256 tokenID)
        external
        view
        returns (address);

    function usedWeights(address user) external view returns (uint256);
}

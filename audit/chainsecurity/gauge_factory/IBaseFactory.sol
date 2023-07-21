/**
 * @title Interface Base V1 Factory
 * @dev IBaseV1Factory.sol contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: Business Source License 1.1
 *
 **/

pragma solidity =0.8.17;

interface IBaseFactory {
    function isPaused() external view returns (bool);

    function owner() external view returns (address);

    function pendingOwner() external view returns (address);

    function admin() external view returns (address);

    function feeAmountOwner() external view returns (address);

    function baseStableFee() external view returns (uint256);

    function baseVariableFee() external view returns (uint256);

    function getPair(
        address token0,
        address token1,
        bool stable
    ) external view returns (address);

    function allPairs(uint256 id) external view returns (address);

    function isPair(address pair) external view returns (bool);

    function protocolAddresses(address pair) external view returns (address);

    function usdfiMaker() external view returns (address);

    function maxGasPrice() external view returns (uint256);

    function setBaseVariableFee(uint256 fee) external;

    function setMaxGasPrice(uint256 gas) external;

    function allPairsLength() external view returns (uint256);

    function setOwner(address owner) external;

    function acceptOwner() external;

    function setPause(bool state) external;

    function setProtocolAddress(address pair, address protocolAddress) external;

    function setAdmins(
        address usdfiMaker,
        address feeAmountOwner,
        address admin
    ) external;

    function pairCodeHash() external pure returns (bytes32);

    function getInitializable()
        external
        view
        returns (
            address,
            address,
            bool
        );

    function createPair(
        address tokenA,
        address tokenB,
        bool stable
    ) external returns (address pair);
}

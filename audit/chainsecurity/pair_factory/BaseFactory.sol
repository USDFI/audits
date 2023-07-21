/**
 * @title Base Factory
 * @dev BaseFactory.sol contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: Business Source License 1.1
 *
 **/

pragma solidity =0.8.17;

import "./BasePair.sol";
import "./IBaseFactory.sol";

contract BaseFactory is IBaseFactory {
    bool public isPaused;
    address public owner;
    address public pendingOwner;
    address public admin;
    address public feeAmountOwner;

    uint256 public baseStableFee = 2500; // 0.04%
    uint256 public baseVariableFee = 333; // 0.3%

    mapping(address => mapping(address => mapping(bool => address)))
        public getPair;
    address[] public allPairs;
    mapping(address => bool) public isPair; // simplified check if its a pair, given that `stable` flag might not be available in peripherals

    address internal _temp0;
    address internal _temp1;
    bool internal _temp;

    mapping(address => address) public protocolAddresses; // pair => protocolAddress
    address public usdfiMaker;

    uint256 public maxGasPrice; // 1000000000 == 1 gwei

    event PairCreated(
        address indexed token0,
        address indexed token1,
        bool stable,
        address pair,
        uint256 allPairsLength
    );
    event SetAdmins(address usdfiMaker, address feeAmountOwner, address admin);
    event SetProtocolAddress(address pair, address protocolAddress);
    event SetPause(bool statePause);
    event AcceptOwner(address newOwner);
    event SetOwner(address newPendingOwner);
    event SetMaxGasPrice(uint256 maxGas);
    event SetBaseVariableFee(uint256 fee);
    event SetBaseStableFee(uint256 fee);

    constructor() {
        owner = msg.sender;
        feeAmountOwner = msg.sender;
    }

    // set the fee for all new stable-LPs
    // 10 max fees for LPs (10%)
    // 10000 min fees for LPs (0.01%)
    function setBaseStableFee(uint256 _fee) external {
        require(msg.sender == owner);
        require(_fee >= 10 && _fee <= 1000, "!range");
        baseStableFee = _fee;

        emit SetBaseStableFee(_fee);
    }

    // set the fee for all new variable-LPs
    // 10 max fees for LPs (10%)
    // 10000 min fees for LPs (0.01%)
    function setBaseVariableFee(uint256 _fee) external {
        require(msg.sender == owner);
        require(_fee >= 10 && _fee <= 1000, "!range");
        baseVariableFee = _fee;

        emit SetBaseVariableFee(_fee);
    }

    // set with which max gas swaps can be performed / 0 for stop max gas
    function setMaxGasPrice(uint256 _gas) external {
        require(msg.sender == owner, "Pair: only owner or admin");
        maxGasPrice = _gas;

        emit SetMaxGasPrice(_gas);
    }

    // return the quantity of all LPs
    function allPairsLength() external view returns (uint256) {
        return allPairs.length;
    }

    // set new Owner for the Factory
    function setOwner(address _owner) external {
        require(msg.sender == owner);
        pendingOwner = _owner;

        emit SetOwner(_owner);
    }

    // pending owner accepts owner
    function acceptOwner() external {
        require(msg.sender == pendingOwner);
        owner = pendingOwner;

        emit AcceptOwner(pendingOwner);
    }

    // set the swaps on pause (only swaps)
    function setPause(bool _state) external {
        require(msg.sender == owner || msg.sender == admin);
        isPaused = _state;

        emit SetPause(_state);
    }

    // set the external protocol address for special fees
    function setProtocolAddress(address _pair, address _protocolAddress)
        external
    {
        require(msg.sender == owner || msg.sender == admin);
        protocolAddresses[_pair] = _protocolAddress;

        emit SetProtocolAddress(_pair, _protocolAddress);
    }

    // set the government admins
    function setAdmins(
        address _usdfiMaker,
        address _feeAmountOwner,
        address _admin
    ) external {
        require(msg.sender == owner || msg.sender == admin);
        usdfiMaker = _usdfiMaker;
        feeAmountOwner = _feeAmountOwner;
        admin = _admin;

        emit SetAdmins(_usdfiMaker, _feeAmountOwner, _admin);
    }

    // return keccak256 creationCode
    function pairCodeHash() external pure returns (bytes32) {
        return keccak256(type(BasePair).creationCode);
    }

    function getInitializable()
        external
        view
        returns (
            address,
            address,
            bool
        )
    {
        return (_temp0, _temp1, _temp);
    }

    // create an new LP pair
    function createPair(
        address tokenA,
        address tokenB,
        bool stable
    ) external returns (address pair) {
        require(tokenA != tokenB, "IA"); // BaseV1: IDENTICAL_ADDRESSES
        (address token0, address token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "ZA"); // BaseV1: ZERO_ADDRESS
        require(getPair[token0][token1][stable] == address(0), "PE"); // BaseV1: PAIR_EXISTS - single check is sufficient
        bytes32 salt = keccak256(abi.encodePacked(token0, token1, stable)); // notice salt includes stable as well, 3 parameters
        (_temp0, _temp1, _temp) = (token0, token1, stable);
        pair = address(new BasePair{salt: salt}());
        getPair[token0][token1][stable] = pair;
        getPair[token1][token0][stable] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        isPair[pair] = true;
        emit PairCreated(token0, token1, stable, pair, allPairs.length);
    }
}

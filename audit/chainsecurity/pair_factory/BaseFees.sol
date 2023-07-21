/**
 * @title Base Fees
 * @dev BaseFees.sol contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: Business Source License 1.1
 *
 **/

pragma solidity =0.8.17;

import "./BaseFactory.sol";
import "./Math.sol";
import "./IERC20.sol";
import "./IBaseFees.sol";

// Base V1 Fees contract is used as a 1:1 pair relationship to split out fees, this ensures that the curve does not need to be modified for LP shares
contract BaseFees is IBaseFees {
    address internal immutable factory; // Factory that created the pairs
    address internal immutable pair; // The pair it is bonded to
    address internal immutable token0; // token0 of pair, saved locally and statically for gas optimization
    address internal immutable token1; // Token1 of pair, saved locally and statically for gas optimization

    uint256 public protocolFee = 0;
    uint256 public usdfiMakerFee = 800;
    uint256 public lpOwnerFee = 200;

    event feeAmountUpdated(
        uint256 prevProtocolFee,
        uint256 indexed protocolFee,
        uint256 prevUsdfiMakerFee,
        uint256 indexed usdfiMakerFee,
        uint256 prevLpOwnerFee,
        uint256 indexed lpOwnerFee
    );

    constructor(
        address _token0,
        address _token1,
        address _factory
    ) {
        pair = msg.sender;
        factory = _factory;
        token0 = _token0;
        token1 = _token1;
    }

    function _safeTransfer(
        address token,
        address to,
        uint256 value
    ) internal {
        require(token.code.length > 0);
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(IERC20.transfer.selector, to, value)
        );
        require(success && (data.length == 0 || abi.decode(data, (bool))));
    }

    // Allow the pair to transfer fees to users
    function claimFeesFor(
        address recipient,
        uint256 amount0,
        uint256 amount1
    ) external returns (uint256 claimed0, uint256 claimed1) {
        require(msg.sender == pair);
        uint256 _divisor = 1000;

        // send X% to protocol address if protocol address exists
        address protocolAddress = BaseFactory(factory).protocolAddresses(pair);
        if (protocolAddress != address(0x0) && protocolFee > 0) {
            if (amount0 > 0)
                _safeTransfer(
                    token0,
                    protocolAddress,
                    (amount0 * protocolFee) / _divisor
                );
            if (amount1 > 0)
                _safeTransfer(
                    token1,
                    protocolAddress,
                    (amount1 * protocolFee) / _divisor
                );
        }

        // send X% to usdfiMaker
        address usdfiMaker = BaseFactory(factory).usdfiMaker();
        if (usdfiMaker != address(0x0)) {
            if (amount0 > 0)
                _safeTransfer(
                    token0,
                    usdfiMaker,
                    (amount0 * usdfiMakerFee) / _divisor
                );
            if (amount1 > 0)
                _safeTransfer(
                    token1,
                    usdfiMaker,
                    (amount1 * usdfiMakerFee) / _divisor
                );
        }

        claimed0 = (amount0 * lpOwnerFee) / _divisor;
        claimed1 = (amount1 * lpOwnerFee) / _divisor;

        // send the rest to owner of LP
        if (amount0 > 0) _safeTransfer(token0, recipient, claimed0);
        if (amount1 > 0) _safeTransfer(token1, recipient, claimed1);
    }

    /**
     * @dev Updates the fees
     *
     * - updates the share of fees attributed to the given protocol
     * - updates the share of fees attributed to the given buyback protocol
     * - updates the share of fees attributed to the given lp owner
     *
     * Can only be called by the factory's owner (feeAmountOwner)
     */
    function setFeeAmount(
        uint256 _protocolFee,
        uint256 _usdfiMakerFee,
        uint256 _lpOwnerFee
    ) external {
        require(
            msg.sender == BaseFactory(factory).feeAmountOwner() ||
                msg.sender == BaseFactory(factory).admin(),
            "Pair: only factory's feeAmountOwner or admin"
        );
        require(
            _protocolFee + _usdfiMakerFee + _lpOwnerFee == 1000,
            "Pair: not 100%"
        );
        require(_usdfiMakerFee >= 10, "Pair: need more then 1%");
        require(_lpOwnerFee >= 10, "Pair: need more then 1%");

        uint256 prevProtocolFee = protocolFee;
        protocolFee = _protocolFee;

        uint256 prevUsdfiMakerFee = usdfiMakerFee;
        usdfiMakerFee = _usdfiMakerFee;

        uint256 prevLpOwnerFee = lpOwnerFee;
        lpOwnerFee = _lpOwnerFee;

        emit feeAmountUpdated(
            prevProtocolFee,
            protocolFee,
            prevUsdfiMakerFee,
            usdfiMakerFee,
            prevLpOwnerFee,
            lpOwnerFee
        );
    }
}

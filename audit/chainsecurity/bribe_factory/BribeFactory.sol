/**
 * @title Bribe Factory
 * @dev BribeFactory.sol contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: Business Source License 1.1
 *
 **/

pragma solidity =0.8.17;

import "./Bribe.sol";
import "./IBribeFactory.sol";

contract BribeFactory is IBribeFactory {
    address public last_bribe;

    function createBribe(address _token0, address _token1)
        external
        returns (address)
    {
        Bribe lastBribe = new Bribe(msg.sender, address(this));
        lastBribe.addRewardtoken(_token0);
        lastBribe.addRewardtoken(_token1);
        last_bribe = address(lastBribe);
        emit CreateBribe(last_bribe, _token0, _token1);
        return last_bribe;
    }

    event CreateBribe(address last_bribe, address token0, address token1);
}

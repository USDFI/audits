/**
 * @title Protocol Governance
 * @dev ProtocolGovernance.sol contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: Business Source License 1.1
 *
 **/

pragma solidity =0.8.17;

import "./IProtocolGovernance.sol";

contract ProtocolGovernance is IProtocolGovernance {
    /// @notice governance address for the governance contract
    address public governance;
    address public pendingGovernance;
    address public admin; //Admin address to manage gauges like add/deprecate/resurrect
    address public voter; //Admin address to manage voting
    address public stableMiner; // Address for stable miner

    // Base fee variables
    address public baseReferralsContract;
    uint256 public baseReferralFee = 2000;
    address public mainRefFeeReceiver;

    /**
     * @notice Allows governance to change governance (for future upgradability)
     * @param _governance new governance address to set
     */
    function setGovernance(address _governance) external {
        require(msg.sender == governance, "setGovernance: !gov");
        pendingGovernance = _governance;

        emit SetGovernance(pendingGovernance);
    }

    /**
     * @notice Allows pendingGovernance to accept their role as governance (protection pattern)
     */
    function acceptGovernance() external {
        require(
            msg.sender == pendingGovernance,
            "acceptGovernance: !pendingGov"
        );
        governance = pendingGovernance;

        emit AcceptGovernance(governance);
    }

    /**
     * @notice Allows governance to change governance (for future upgradability)
     * @param _admin new admin address to set
     * @param _voter new voter address to set
     */
    function setAdminAndVoter(address _admin, address _voter) external {
        require(msg.sender == governance, "!gov");
        admin = _admin;
        voter = _voter;
        emit SetAdminAndVoter(admin, voter);
    }

    // Set Stable-miner
    function setStableMiner(address _stableMiner) external {
        require(msg.sender == governance || msg.sender == admin, "!gov");
        stableMiner = _stableMiner;
        emit SetStableMiner(stableMiner);
    }

    // Update the base referral contract and base referral fee and the main referral fee receiver
    function updateBaseReferrals(
        address _referralsContract,
        uint256 _baseReferralFee,
        address _mainRefFeeReceiver
    ) public {
        require(
            (msg.sender == governance || msg.sender == admin),
            "!gov or !admin"
        );
        require((_baseReferralFee <= 10000), "must be lower 10%");
        baseReferralsContract = _referralsContract;
        baseReferralFee = _baseReferralFee;
        mainRefFeeReceiver = _mainRefFeeReceiver;
        emit UpdateBaseReferrals(
            baseReferralsContract,
            baseReferralFee,
            mainRefFeeReceiver
        );
    }

    event UpdateBaseReferrals(
        address referralContract,
        uint256 referralFee,
        address refLevelPercent
    );
    event SetStableMiner(address stableMiner);
    event SetAdminAndVoter(address admin, address voter);
    event SetGovernance(address pendingGovernance);
    event AcceptGovernance(address governance);
}

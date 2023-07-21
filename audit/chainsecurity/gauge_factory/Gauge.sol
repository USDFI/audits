/**
 * @title Gauge
 * @dev Gauge.sol contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: Business Source License 1.1
 *
 **/

pragma solidity =0.8.17;

import "./SafeERC20.sol";
import "./Math.sol";
import "./ReentrancyGuard.sol";
import "./IBasePair.sol";
import "./IBaseFactory.sol";
import "./IBribe.sol";
import "./IGaugeFactory.sol";
import "./ProtocolGovernance.sol";
import "./IReferrals.sol";
import "./IGauge.sol";

contract Gauge is IGauge, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable STABLE;
    IERC20 public immutable TOKEN;
    address private immutable token;

    uint256 public constant DURATION = 1 weeks;
    uint256 public periodFinish = 0;
    uint256 public rewardRate = 0;
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    uint256 public fees0;
    uint256 public fees1;

    address public immutable gaugeFactory;
    address public referralContract;

    mapping(address => mapping(address => bool)) public whitelisted;
    mapping(address => uint256) public earnedRefs;

    /**
     * @dev Outputs the fee variables.
     */
    uint256 public referralFee;
    uint256[] public refLevelPercent = [60000, 30000, 10000];

    uint256 internal divisor = 100000;

    modifier onlyDistribution() {
        require(
            msg.sender == gaugeFactory,
            "Caller is not RewardsDistribution contract"
        );
        _;
    }

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    uint256 private _totalSupply;
    uint256 public derivedSupply;
    mapping(address => uint256) private _balances;
    mapping(address => uint256) public derivedBalances;
    mapping(address => uint256) private _base;

    constructor(
        address _stable,
        address _token,
        address _gaugeFactory
    ) public {
        STABLE = IERC20(_stable);
        TOKEN = IERC20(_token);
        token = _token;
        gaugeFactory = _gaugeFactory;
        referralContract = IProtocolGovernance(gaugeFactory)
            .baseReferralsContract();
        referralFee = IProtocolGovernance(gaugeFactory).baseReferralFee();
    }

    // Claim the fees from the LP token and Bribe to the voter
    function claimVotingFees()
        external
        nonReentrant
        returns (uint256 claimed0, uint256 claimed1)
    {
        return _claimVotingFees();
    }

    function _claimVotingFees()
        internal
        returns (uint256 claimed0, uint256 claimed1)
    {
        (claimed0, claimed1) = IBasePair(address(TOKEN)).claimFees();
        if (claimed0 > 0 || claimed1 > 0) {
            address bribe = IGaugeFactory(gaugeFactory).bribes(address(this));
            uint256 _fees0 = fees0 + claimed0;
            uint256 _fees1 = fees1 + claimed1;
            (address _token0, address _token1) = IBasePair(address(TOKEN))
                .tokens();
            if (_fees0 > DURATION) {
                fees0 = 0;
                IERC20(_token0).safeApprove(bribe, _fees0);
                IBribe(bribe).notifyRewardAmount(_token0, _fees0);
            } else {
                fees0 = _fees0;
            }
            if (_fees1 > DURATION) {
                fees1 = 0;
                IERC20(_token1).safeApprove(bribe, _fees1);
                IBribe(bribe).notifyRewardAmount(_token1, _fees1);
            } else {
                fees1 = _fees1;
            }

            emit ClaimVotingFees(msg.sender, claimed0, claimed1);
        }
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        if (derivedSupply == 0) {
            return 0;
        }

        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            (((lastTimeRewardApplicable() - lastUpdateTime) *
                rewardRate *
                1e18) / derivedSupply);
    }

    // The derivedBalance function calculates the derived balance of an account, which is used to determine the amount of rewards earned by the account.
    function derivedBalance(address account) public view returns (uint256) {
        if (IGaugeFactory(gaugeFactory).weights(token) == 0) return 0;
        uint256 _balance = _balances[account];
        uint256 _derived = (_balance * 40) / 100;
        uint256 _adjusted = ((((_totalSupply *
            IGaugeFactory(gaugeFactory).votes(account, token)) /
            IGaugeFactory(gaugeFactory).weights(token)) * 60) / 100);
        return Math.min(_derived + _adjusted, _balance);
    }

    // The kick function updates the derived balance of an account and the total derived supply of the contract
    function kick(address account) public {
        uint256 _derivedBalance = derivedBalances[account];
        derivedSupply = derivedSupply - _derivedBalance;
        _derivedBalance = derivedBalance(account);
        derivedBalances[account] = _derivedBalance;
        derivedSupply = derivedSupply + _derivedBalance;
        emit Kick(account);
    }

    // Your earned rewards (without referrals deduction)
    function earned(address account) public view returns (uint256) {
        if (derivedSupply == 0) {
            return rewards[account];
        }
        return
            ((derivedBalances[account] *
                (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18) +
            rewards[account];
    }

    // How many rewards will be distributed this epoch
    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * DURATION;
    }

    // Deposit LP token
    function deposit(uint256 amount) external {
        _deposit(amount, msg.sender);
    }

    function depositFor(uint256 amount, address account) external {
        _deposit(amount, account);
    }

    function _deposit(uint256 amount, address account)
        internal
        nonReentrant
        updateReward(account)
    {
        require(account != address(0), "cannot deposit to address 0");
        require(amount > 0, "deposit(Gauge): cannot stake 0");

        _balances[account] = _balances[account] + amount;
        _totalSupply = _totalSupply + amount;

        TOKEN.safeTransferFrom(msg.sender, address(this), amount);

        emit Staked(account, amount);
    }

    // Withdraw LP token
    function withdraw(uint256 amount) external {
        _withdraw(amount);
    }

    function _withdraw(uint256 amount)
        internal
        nonReentrant
        updateReward(msg.sender)
    {
        require(amount > 0, "Cannot withdraw 0");
        _totalSupply = _totalSupply - amount;
        _balances[msg.sender] = _balances[msg.sender] - amount;
        TOKEN.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    // Claim your rewards
    function getReward() external {
        getRewardForOwnerToOtherOwner(msg.sender, msg.sender);
    }

    // Give the owner the earned rewards
    function getRewardForOwner(address _owner) external {
        getRewardForOwnerToOtherOwner(_owner, _owner);
    }

    // Get the reward from a owner to a whistlistet address or self
    function getRewardForOwnerToOtherOwner(address _owner, address _receiver)
        public
        nonReentrant
        updateReward(_owner)
    {
        uint256 reward = rewards[_owner];
        if (reward > 0) {
            if (_owner != _receiver) {
                require(
                    _owner == msg.sender ||
                        whitelisted[_owner][_receiver] == true,
                    "not owner or whitelisted"
                );
            }
            uint256 _divisor = divisor;
            rewards[_owner] = 0;

            uint256 refReward = (reward * referralFee) / _divisor;
            uint256 remainingRefReward = refReward;

            STABLE.safeTransfer(_receiver, reward - refReward);
            emit RewardPaid(_owner, _receiver, reward - refReward);

            address ref = IReferrals(referralContract).getSponsor(_owner);

            uint256 i = 0;
            while (i < refLevelPercent.length && refLevelPercent[i] > 0) {
                if (ref != IReferrals(referralContract).membersList(0)) {
                    uint256 refFeeAmount = (refReward * refLevelPercent[i]) /
                        _divisor;
                    remainingRefReward = remainingRefReward - refFeeAmount;
                    STABLE.safeTransfer(ref, refFeeAmount);
                    earnedRefs[ref] = earnedRefs[ref] + refFeeAmount;
                    emit RefRewardPaid(ref, reward);
                    ref = IReferrals(referralContract).getSponsor(ref);
                    i++;
                } else {
                    break;
                }
            }
            if (remainingRefReward > 0) {
                address _mainRefFeeReceiver = IProtocolGovernance(gaugeFactory)
                    .mainRefFeeReceiver();
                STABLE.safeTransfer(_mainRefFeeReceiver, remainingRefReward);
                earnedRefs[_mainRefFeeReceiver] =
                    earnedRefs[_mainRefFeeReceiver] +
                    remainingRefReward;
                emit RefRewardPaid(_mainRefFeeReceiver, remainingRefReward);
            }
        }
    }

    // Notify rewards for the LP depositer
    function notifyRewardAmount(uint256 reward)
        external
        onlyDistribution
        updateReward(address(0))
    {
        if (derivedSupply != 0) {
        STABLE.safeTransferFrom(gaugeFactory, address(this), reward);
            if (block.timestamp >= periodFinish) {
                rewardRate = reward / DURATION;
            } else {
                uint256 remaining = periodFinish - block.timestamp;
                uint256 leftover = remaining * rewardRate;
                rewardRate = (reward + leftover) / DURATION;
            }
        }
        // Ensure the provided reward amount is not more than the balance in the contract.
        // This keeps the reward rate in the right range, preventing overflows due to
        // very high values of rewardRate in the earned and rewardsPerToken functions;
        // Reward + leftover must be less than 2^256 / 10^18 to avoid overflow.
        uint256 balance = STABLE.balanceOf(address(this));
        require(rewardRate <= balance / DURATION, "Provided reward too high");

        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + DURATION;
        emit RewardAdded(reward);
    }

    // Update the rewards
    modifier updateReward(address account) {
        if (block.timestamp > IGaugeFactory(gaugeFactory).nextPoke(account)) {
            IGaugeFactory(gaugeFactory).poke(account);
        }
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
        if (account != address(0)) {
            kick(account);
        }
    }

    // Update the referral variables
    function updateReferral(
        address _referralsContract,
        uint256 _referralFee,
        uint256[] memory _refLevelPercent
    ) public {
        require(
            msg.sender == IProtocolGovernance(gaugeFactory).governance() ||
                msg.sender == IProtocolGovernance(gaugeFactory).admin(),
            "Pair: only factory's feeAmountOwner or admin"
        );
        referralContract = _referralsContract;
        referralFee = _referralFee;
        refLevelPercent = _refLevelPercent;
        emit UpdateReferral(referralContract, referralFee, refLevelPercent);
    }

    // Set whitelist for other receiver
    function setWhitelisted(address _receiver, bool _whitelist) public {
        whitelisted[msg.sender][_receiver] = _whitelist;
        emit Whitelisted(msg.sender, _receiver);
    }

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(
        address indexed user,
        address indexed receiver,
        uint256 reward
    );
    event RefRewardPaid(address indexed user, uint256 reward);
    event ClaimVotingFees(
        address indexed from,
        uint256 claimed0,
        uint256 claimed1
    );
    event Whitelisted(address user, address whitelistedUser);
    event UpdateReferral(
        address referralContract,
        uint256 referralFee,
        uint256[] refLevelPercent
    );
    event Kick(address account);
}

/**
 * @title Bribe
 * @dev Bribe.sol contract
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
import "./IReferrals.sol";
import "./IGaugeFactory.sol";
import "./IBribe.sol";
import "./IProtocolGovernance.sol";

contract Bribe is IBribe, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant WEEK = 1 weeks; // rewards are released over 7 days
    uint256 public firstBribeTimestamp;

    /* ========== STATE VARIABLES ========== */

    struct Reward {
        uint256 periodFinish;
        uint256 rewardsPerEpoch;
        uint256 lastUpdateTime;
    }

    mapping(address => mapping(uint256 => Reward)) public rewardData; // token -> startTimestamp -> Reward
    mapping(address => bool) public isRewardToken;
    address[] public rewardTokens;
    address public gaugeFactory;
    address public bribeFactory;

    // user -> reward token -> lastTime
    mapping(address => mapping(address => uint256)) public userTimestamp;

    // uint256 private _totalSupply;
    mapping(uint256 => uint256) public _totalSupply;
    mapping(address => mapping(uint256 => uint256)) public _balances; //user -> timestamp -> amount

    // outputs the fee variables.
    uint256 public referralFee;
    address public referralContract;
    uint256[] public refLevelPercent = [60000, 30000, 10000];
    uint256 internal divisor = 100000;

    // user -> reward token -> earned amount
    mapping(address => mapping(address => uint256)) public earnedRefs;
    mapping(address => mapping(address => bool)) public whitelisted;

    mapping(address => uint256) public userFirstDeposit;

    /* ========== CONSTRUCTOR ========== */

    constructor(address _gaugeFactory, address _bribeFactory) public {
        gaugeFactory = _gaugeFactory;
        bribeFactory = _bribeFactory;
        firstBribeTimestamp = IGaugeFactory(_gaugeFactory).epoch();
        referralContract = IProtocolGovernance(_gaugeFactory)
            .baseReferralsContract();
        referralFee = IProtocolGovernance(_gaugeFactory).baseReferralFee();
    }

    /* ========== VIEWS ========== */

    function getEpoch() public view returns (uint256) {
        return IGaugeFactory(gaugeFactory).epoch();
    }

    function rewardsListLength() external view returns (uint256) {
        return rewardTokens.length;
    }

    function totalSupply() external view returns (uint256) {
        uint256 _currentEpochStart = getEpoch(); // claim until current epoch
        return _totalSupply[_currentEpochStart];
    }

    function totalSupplyNextEpoch() external view returns (uint256) {
        uint256 _currentEpochStart = getEpoch() + 1; // claim until current epoch
        return _totalSupply[_currentEpochStart];
    }

    function totalSupplyAt(uint256 _timestamp) external view returns (uint256) {
        return _totalSupply[_timestamp];
    }

    function balanceOfAt(address _voter, uint256 _timestamp)
        public
        view
        returns (uint256)
    {
        return _balances[_voter][_timestamp];
    }

    // Get last deposit available balance (getNextEpochStart)
    function balanceOf(address _voter) public view returns (uint256) {
        uint256 _timestamp = getEpoch() + 1;
        return _balances[_voter][_timestamp];
    }

    // Calculates the total rewards earned by a user for a particular reward token.
    // If a user has not collected any rewards for 50 epochs (about 1 year), they are lost the upcoming rewards.
    // We believe that it's not logical to assume that a user actively votes in the protocol’s governance,
    // but does not claim his rewards for 50 consecutive weeks which are visibly on display every time he votes using the frontend. 
    function earned(address _voter, address _rewardToken)
        public
        view
        returns (uint256)
    {
        uint256 k = 0;
        uint256 reward = 0;
        uint256 _endTimestamp = getEpoch(); // claim until current epoch
        uint256 _userLastTime = userTimestamp[_voter][_rewardToken];

        if (_endTimestamp == _userLastTime) {
            return 0;
        }

        // if user first time then set it to first bribe
        if (_userLastTime == 0) {
            _userLastTime = userFirstDeposit[_voter];
        }

        for (k; k < 50; k++) {
            if (_userLastTime == _endTimestamp) {
                // if we reach the current epoch, exit
                break;
            }
            reward += _earned(_voter, _rewardToken, _userLastTime);
            _userLastTime += 1;
        }
        return reward;
    }

    function _earned(
        address _voter,
        address _rewardToken,
        uint256 _timestamp
    ) public view returns (uint256) {
        uint256 _balance = balanceOfAt(_voter, _timestamp);
        if (_balance == 0) {
            return 0;
        } else {
            uint256 _rewardPerToken = rewardPerToken(_rewardToken, _timestamp);
            uint256 _rewards = (_rewardPerToken * _balance) / 1e18;
            return _rewards;
        }
    }

    // Calculates the reward per token for a given rewards token and timestamp
    function rewardPerToken(address _rewardsToken, uint256 _timestamap)
        public
        view
        returns (uint256)
    {
        if (_totalSupply[_timestamap] == 0) {
            return rewardData[_rewardsToken][_timestamap].rewardsPerEpoch;
        }
        return
            (rewardData[_rewardsToken][_timestamap].rewardsPerEpoch * 1e18) /
            _totalSupply[_timestamap];
    }

    //---------------------------

    // GaugeFactory deposit Votingpower amount for voter
    function _deposit(uint256 amount, address _voter) external nonReentrant {
        require(amount > 0, "Cannot stake 0");
        require(msg.sender == gaugeFactory);
        uint256 _startTimestamp = getEpoch() + 1;
        if (userFirstDeposit[_voter] == 0) {
            userFirstDeposit[_voter] = _startTimestamp;
        }
        uint256 _oldSupply = _totalSupply[_startTimestamp];
        _totalSupply[_startTimestamp] = _oldSupply + amount;
        _balances[_voter][_startTimestamp] =
            _balances[_voter][_startTimestamp] +
            amount;
        emit Staked(_voter, amount);
    }

    // GaugeFactory withdraw Votingpower amount for voter
    function _withdraw(uint256 amount, address _voter) public nonReentrant {
        require(amount > 0, "Cannot withdraw 0");
        require(msg.sender == gaugeFactory);
        uint256 _startTimestamp = getEpoch() + 1;
        if (amount <= _balances[_voter][_startTimestamp]) {
            uint256 _oldSupply = _totalSupply[_startTimestamp];
            uint256 _oldBalance = _balances[_voter][_startTimestamp];
            _totalSupply[_startTimestamp] = _oldSupply - amount;
            _balances[_voter][_startTimestamp] = _oldBalance - amount;
            emit Withdrawn(_voter, amount);
        }
    }

    // depostit rewards in rewardToken for next epoch
    function notifyRewardAmount(address _rewardsToken, uint256 reward)
        external
        nonReentrant
    {
        require(isRewardToken[_rewardsToken], "reward token not verified");
        require(reward > WEEK, "reward amount should be greater than DURATION");
        IERC20(_rewardsToken).safeTransferFrom(
            msg.sender,
            address(this),
            reward
        );

        uint256 _startTimestamp = getEpoch() + 1; // period points to the current distribute day. Bribes are distributed from next epoch in 7 days
        if (firstBribeTimestamp == 0) {
            firstBribeTimestamp = _startTimestamp;
        }

        uint256 _lastReward = rewardData[_rewardsToken][_startTimestamp]
            .rewardsPerEpoch;

        rewardData[_rewardsToken][_startTimestamp].rewardsPerEpoch =
            _lastReward +
            reward;
        rewardData[_rewardsToken][_startTimestamp].lastUpdateTime = block
            .timestamp;
        rewardData[_rewardsToken][_startTimestamp].periodFinish =
            getEpoch() +
            1;

        emit RewardAdded(_rewardsToken, reward, _startTimestamp);
    }

    // Claim all your rewards
    function getReward() external {
        getRewardForOwnerToOtherOwner(msg.sender, msg.sender);
    }

    // Give the owner all earned rewards
    function getRewardForOwner(address voter) external {
        getRewardForOwnerToOtherOwner(voter, voter);
    }

    // Get the reward from a owner to a whistlistet address or self
    function getRewardForOwnerToOtherOwner(address _voter, address _receiver)
        public
        nonReentrant
    {
        if (_voter != _receiver) {
            require(
                _voter == msg.sender || whitelisted[_voter][_receiver] == true,
                "not owner or whitelisted"
            );
        }

        uint256 _endTimestamp = getEpoch(); // claim until current epoch
        uint256 reward = 0;

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            address _rewardToken = rewardTokens[i];
            reward = earned(_voter, _rewardToken);

            if (reward > 0) {
                uint256 _divisor = divisor;
                uint256 refReward = (reward * referralFee) / _divisor;
                uint256 remainingRefReward = refReward;

                IERC20(_rewardToken).safeTransfer(
                    _receiver,
                    reward - refReward
                );
                emit RewardPaid(
                    _voter,
                    _receiver,
                    _rewardToken,
                    reward - refReward
                );
                address ref = IReferrals(referralContract).getSponsor(_voter);

                uint256 x = 0;
                while (x < refLevelPercent.length && refLevelPercent[x] > 0) {
                    if (ref != IReferrals(referralContract).membersList(0)) {
                        uint256 refFeeAmount = (refReward *
                            refLevelPercent[x]) / _divisor;
                        remainingRefReward = remainingRefReward - refFeeAmount;
                        IERC20(_rewardToken).safeTransfer(ref, refFeeAmount);
                        earnedRefs[ref][_rewardToken] =
                            earnedRefs[ref][_rewardToken] +
                            refFeeAmount;
                        emit RefRewardPaid(ref, _rewardToken, reward);
                        ref = IReferrals(referralContract).getSponsor(ref);
                        x++;
                    } else {
                        break;
                    }
                }
                if (remainingRefReward > 0) {
                    address _mainRefFeeReceiver = IProtocolGovernance(
                        gaugeFactory
                    ).mainRefFeeReceiver();
                    IERC20(_rewardToken).safeTransfer(
                        _mainRefFeeReceiver,
                        remainingRefReward
                    );
                    earnedRefs[_mainRefFeeReceiver][_rewardToken] =
                        earnedRefs[_mainRefFeeReceiver][_rewardToken] +
                        remainingRefReward;
                    emit RefRewardPaid(
                        _mainRefFeeReceiver,
                        _rewardToken,
                        remainingRefReward
                    );
                }
            }
            userTimestamp[_voter][_rewardToken] = _endTimestamp;
        }
    }

    // Same like getRewardForOwnerToOtherOwner but with Single Token claim (in case one is broken or pause)
    function getRewardForOwnerToOtherOwnerSingleToken(
        address _voter,
        address _receiver,
        address[] calldata tokens
    ) external nonReentrant {
        if (_voter != _receiver) {
            require(
                _voter == msg.sender || whitelisted[_voter][_receiver] == true,
                "not owner or whitelisted"
            );
        }

        uint256 _endTimestamp = getEpoch(); // claim until current epoch
        uint256 reward = 0;

        for (uint256 i = 0; i < tokens.length; i++) {
            address _rewardToken = tokens[i];
            reward = earned(_voter, _rewardToken);

            if (reward > 0) {
                uint256 _divisor = divisor;
                uint256 refReward = (reward * referralFee) / _divisor;
                uint256 remainingRefReward = refReward;

                IERC20(_rewardToken).safeTransfer(
                    _receiver,
                    reward - refReward
                );
                emit RewardPaid(
                    _voter,
                    _receiver,
                    _rewardToken,
                    reward - refReward
                );
                address ref = IReferrals(referralContract).getSponsor(_voter);

                uint256 x = 0;
                while (x < refLevelPercent.length && refLevelPercent[x] > 0) {
                    if (ref != IReferrals(referralContract).membersList(0)) {
                        uint256 refFeeAmount = (refReward *
                            refLevelPercent[x]) / _divisor;
                        remainingRefReward = remainingRefReward - refFeeAmount;
                        IERC20(_rewardToken).safeTransfer(ref, refFeeAmount);
                        earnedRefs[ref][_rewardToken] =
                            earnedRefs[ref][_rewardToken] +
                            refFeeAmount;
                        emit RefRewardPaid(ref, _rewardToken, reward);
                        ref = IReferrals(referralContract).getSponsor(ref);
                        x++;
                    } else {
                        break;
                    }
                }
                if (remainingRefReward > 0) {
                    address _mainRefFeeReceiver = IProtocolGovernance(
                        gaugeFactory
                    ).mainRefFeeReceiver();
                    IERC20(_rewardToken).safeTransfer(
                        _mainRefFeeReceiver,
                        remainingRefReward
                    );
                    earnedRefs[_mainRefFeeReceiver][_rewardToken] =
                        earnedRefs[_mainRefFeeReceiver][_rewardToken] +
                        remainingRefReward;
                    emit RefRewardPaid(
                        _mainRefFeeReceiver,
                        _rewardToken,
                        remainingRefReward
                    );
                }
            }
            userTimestamp[_voter][_rewardToken] = _endTimestamp;
        }
    }

    // Set whitelist for other receiver in getRewardForOwnerToOtherOwner
    function setWhitelisted(address _receiver, bool _whitlist) public {
        whitelisted[msg.sender][_receiver] = _whitlist;
        emit Whitelisted(msg.sender, _receiver);
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    // transfer a token out of the contract that is not a wanted token (airdrop tokens)
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external {
        require(
            msg.sender == IProtocolGovernance(gaugeFactory).governance() ||
                msg.sender == IProtocolGovernance(gaugeFactory).admin(),
            "Pair: only factory's feeAmountOwner or admin"
        );
        require(tokenAmount <= IERC20(tokenAddress).balanceOf(address(this)));
        require(!isRewardToken[tokenAddress], "Reward token not allowed");
        IERC20(tokenAddress).safeTransfer(msg.sender, tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    // add a token as bribe reward token
    function addRewardtoken(address _rewardsToken) external {
        require(
            msg.sender == bribeFactory ||
                msg.sender == IProtocolGovernance(gaugeFactory).governance() ||
                msg.sender == IProtocolGovernance(gaugeFactory).admin(),
            "Pair: only factory's feeAmountOwner or admin"
        );
        require(!isRewardToken[_rewardsToken], "Reward token already exists");
        require(_rewardsToken != address(0));
        isRewardToken[_rewardsToken] = true;
        rewardTokens.push(_rewardsToken);
        emit AddRewardtoken(_rewardsToken);
    }

    /* ========== REFERRAL FUNCTIONS ========== */

    // Update the referral Variables
    function updateReferral(
        address _referralsContract,
        uint256 _referralFee,
        uint256[] calldata _refLevelPercent
    ) external {
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

    /* ========== EVENTS ========== */

    event RewardAdded(
        address rewardToken,
        uint256 reward,
        uint256 startTimestamp
    );
    event Staked(address indexed voter, uint256 amount);
    event Withdrawn(address indexed voter, uint256 amount);
    event RewardPaid(
        address indexed user,
        address indexed rewardsToken,
        uint256 reward
    );
    event Recovered(address token, uint256 amount);
    event RefRewardPaid(
        address indexed user,
        address indexed token,
        uint256 reward
    );
    event RewardPaid(
        address indexed user,
        address indexed receiver,
        address indexed rewardsToken,
        uint256 reward
    );
    event AddRewardtoken(address token);
    event Whitelisted(address user, address whitelistedUser);
    event UpdateReferral(
        address referralContract,
        uint256 referralFee,
        uint256[] refLevelPercent
    );
}

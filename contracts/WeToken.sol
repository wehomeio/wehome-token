pragma solidity ^0.4.18;

import "./StandardToken.sol";


/**
 * WeToken
 *
 * Symbol       : WET
 * Name         : WeToken
 * Total supply : 1,000,000,000
 * Decimals     : 18
 *
 * (c) WeHome, Inc. 2018
 */
contract WeToken is StandardToken {
    string public symbol;
    string public  name;
    uint8 public decimals;

    // deposit address
    address public ethFundDeposit; // ETH deposit address for WeHome
    address public wetFundDeposit; // WET deposit address for WeHome

    // crowdsale related
    bool public isFinalized; // switched to true in operational state
    uint256 public startDate;
    uint256 public earlyBirdEnds;
    uint256 public endDate;

    // crowdsale constant
    uint256 public constant WET_FUND = 500 * (10**6) * 10**18; // 500m WET reserved for WeHome
    uint256 public constant EARLY_BIRD_CAP = 110 * (10**6) * 10**18; // First 110m WET for early bird
    uint256 public constant EARLY_BIRD_RATE = 11000; // 11000 BAT tokens per 1 ETH for early bird
    uint256 public constant EXCHANGE_RATE = 10000; // 10000 BAT tokens per 1 ETH
    uint256 public constant TOKEN_TOTAL_CAP =  1 * (10**9) * 10**18;
    uint256 public constant MIN_TOKEN_TOTAL_CAP =  800 * (10**9) * 10**18;
    uint256 public constant MAX_CONTRIBUTION = 50 * 10**18;

    mapping(address => uint256) public contributes;

    // events
    event RefundETH(address indexed _to, uint256 _value);
    event CreateToken(address indexed _to, uint256 _value);
    event BurnToken(address indexed from, uint256 _value);

    /**
     * Constructor
     */
    function WeToken(
        address _ethFundDeposit,
        address _wetFundDeposit) public {
        symbol = "WET";
        name = "WeToken";
        decimals = 18;

        isFinalized = false;

        ethFundDeposit = _ethFundDeposit;
        wetFundDeposit = _wetFundDeposit;

        startDate = now;
        earlyBirdEnds = now + 1 weeks;
        endDate = now + 4 weeks;

        _totalSupply = WET_FUND;
        balances[wetFundDeposit] = WET_FUND; // Deposit WeHome fund
        CreateToken(wetFundDeposit, WET_FUND);  // logs WeHome fund
    }

    /**
     * Early bird: 1 ETH = 11,000 WET
     * Normal: 1 ETH = 10,000 WET
     */
    function createTokens() external payable {
        require(!isFinalized);
        require(now >= startDate && now <= endDate);
        require(msg.value > 0);

        uint256 contribute = contributes[msg.sender] + msg.value;
        require(contribute <= MAX_CONTRIBUTION);

        uint256 tokens;
        if (now <= earlyBirdEnds && _totalSupply <= EARLY_BIRD_CAP) {
            tokens = msg.value * EARLY_BIRD_RATE;
        } else {
            tokens = msg.value * EXCHANGE_RATE;
        }

        uint256 targetTotalSupply = _totalSupply.add(tokens);
        require(targetTotalSupply <= TOKEN_TOTAL_CAP);

        balances[msg.sender] = balances[msg.sender].add(tokens);
        contributes[msg.sender] = contribute;
        _totalSupply = targetTotalSupply;
        CreateToken(msg.sender, tokens);
    }

    /**
     * Finalize 
     */
    function finalize() external {
        require(!isFinalized);
        // only ETH owner can finalize the crowdsale
        require(msg.sender == ethFundDeposit); 
        // require either end or totalSupply is enough
        require(now >= endDate || _totalSupply == TOKEN_TOTAL_CAP);
        // require minimum token sale
        require(_totalSupply >= MIN_TOKEN_TOTAL_CAP);

        isFinalized = true;
        assert(ethFundDeposit.send(this.balance));
    }

    /**
     * Allows contributors to recover their ether in the case of a failed funding campaign.
     */
    function refund() external {
        require(!isFinalized);
        require(now >= endDate);
        require(msg.sender != wetFundDeposit);
        require(_totalSupply >= MIN_TOKEN_TOTAL_CAP);

        uint256 tokens = balances[msg.sender];
        require(tokens != 0);
        balances[msg.sender] = 0;
        _totalSupply = _totalSupply.sub(tokens);

        uint256 ethContribute = contributes[msg.sender];
        RefundETH(msg.sender, ethContribute);
        // if you're using a contract; make sure it works with .send gas limits
        assert(msg.sender.send(ethContribute));
    }

    /**
     * Burn token
     */
    function burn(uint256 _value) external returns (bool success) {
        require(balances[msg.sender] >= _value);
        require(_value > 0);
        balances[msg.sender] = balances[msg.sender].sub(_value);
        _totalSupply = _totalSupply.sub(_value);
        BurnToken(msg.sender, _value);
        return true;
    }

}

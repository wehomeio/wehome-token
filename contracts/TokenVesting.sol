pragma solidity ^0.4.18;

import "./ERC20Interface.sol";
import "./Ownable.sol";
import "./SafeERC20.sol";
import "./SafeMath.sol";


/**
 * TokenVesting
 *
 * A token holder contract that can release its token balance gradually like a
 * typical vesting scheme, with a cliff and vesting period. Optionally revocable by the
 * owner.
 */
contract TokenVesting is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20Interface;

    event Released(uint256 amount);
    event Revoked();

    // beneficiary of tokens after they are released
    address public beneficiary;

    uint256 public cliff;
    uint256 public start;
    uint256 public duration;

    bool public revocable;

    ERC20Interface public token;

    uint256 public released;
    bool public revoked;

    /**
     * Creates a vesting contract that vests its balance of any ERC20 token to the
     * _beneficiary, gradually in a linear fashion until _start + _duration. By then all
     * of the balance will have vested.
     *
     * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
     * @param _start when vesting start
     * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
     * @param _duration duration in seconds of the period in which the tokens will vest
     * @param _revocable whether the vesting is revocable or not
     * @param _token ERC20 token address
     */
    function TokenVesting(
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        bool _revocable,
        address _token
    ) public {
        require(_beneficiary != address(0));
        require(_cliff <= _duration);

        beneficiary = _beneficiary;
        revocable = _revocable;
        duration = _duration;
        cliff = _start.add(_cliff);
        start = _start;
        token = ERC20Interface(_token);
    }

    /**
     * Only allow calls from the beneficiary of the vesting contract
     */
    modifier onlyBeneficiary() {
        require(msg.sender == beneficiary);
        _;
    }

    /**
     * Allow the beneficiary to change its address
     *
     * @param target the address to transfer the right to
     */
    function changeBeneficiary(address target) public onlyBeneficiary {
        require(target != 0);
        beneficiary = target;
    }

    /**
     * Allow beneficiary to release to themselves
     */
    function release() public onlyBeneficiary {
        require(now >= cliff);
        require(!revoked);
        _releaseTo(beneficiary);
    }

    /**
     * Transfers vested tokens to a target address.
     *
     * @param target the address to send the tokens to
     */
    function releaseTo(address target) public onlyBeneficiary {
        require(now >= cliff);
        require(!revoked);
        _releaseTo(target);
    }

    /**
     * Allows the owner to revoke the vesting. Tokens already vested are sent to the beneficiary.
     */
    function revoke() public onlyOwner {
        require(revocable);
        require(!revoked);

        // Release all vested tokens
        _releaseTo(beneficiary);

        // Send the remainder to the owner
        token.safeTransfer(owner, token.balanceOf(this));

        revoked = true;

        Revoked();
    }

    /**
     * Calculates the amount that has already vested but hasn't been released yet.
     */
    function releasableAmount() public view returns (uint256) {
        return vestedAmount().sub(released);
    }

    /**
     * Calculates the amount that has already vested.
     */
    function vestedAmount() public view returns (uint256) {
        uint256 currentBalance = token.balanceOf(this);
        uint256 totalBalance = currentBalance.add(released);

        if (now < cliff) {
            return 0;
        } else if (now >= start.add(duration)) {
            return totalBalance;
        } else {
            return totalBalance.mul(now.sub(start)).div(duration);
        }
    }

    /**
     * Transfers vested tokens to beneficiary.
     *
     * @param target the address to release to
     */
    function _releaseTo(address target) internal {
        uint256 unreleased = releasableAmount();

        require(unreleased > 0);

        released = released.add(unreleased);

        token.safeTransfer(target, unreleased);

        Released(released);
    }
}

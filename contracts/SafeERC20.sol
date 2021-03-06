pragma solidity ^0.4.18;

import "./ERC20Interface.sol";


library SafeERC20 {
    function safeTransfer(ERC20Interface token, address to, uint256 value) internal {
        assert(token.transfer(to, value));
    }

    function safeTransferFrom(ERC20Interface token, address from, address to, uint256 value) internal {
        assert(token.transferFrom(from, to, value));
    }

    function safeApprove(ERC20Interface token, address spender, uint256 value) internal {
        assert(token.approve(spender, value));
    }
}

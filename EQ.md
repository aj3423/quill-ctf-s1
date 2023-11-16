# Analysis:
We can use storage to compare number `A` and `B`, the pseudo code:
- `slot[B] = 0`
- `slot[A] = 1`
- `return slot[B]`

And some tricks:

- `push1 1`  -> `chainid`,        because `1` is banned
- `push1 4`  -> `callvalue`,      bacause `4` is banned
- `push1 0`  -> `returndatasize`, for saving 1 byte
- The length of runtime code is 0x13 which is banned, pad two bytes `ffff` at the end to make it 0x15 bytes long, which is not banned.
- Also add 1 byte `ff` to deployment code, to prevent runtime code start from banned offset `0x09`.


# Runtime code

| bytes | Mnemonic       | Stack          | Comment         |
| -     | -              | -              | -               |
| 6024  | push1 0x24     | [0x24          | get B as arg 1  |
| 35    | calldataload   | [B             |                 |
| 80    | dup1           | [B, B          |                 |
|
| 3D    | returndatasize | [B, B, 0       |                 |
| 90    | swap1          | [B, 0, B       |                 |
| 55    | sstore         | [B             | slot[B] = 0     |
|
| 34    | callvalue      | [B, 4          | get A as arg 0  |
| 35    | calldataload   | [B, A          |                 |
|
| 46    | chainid        | [B, A, 1       |                 |
| 90    | swap1          | [B, 1, A       |                 |
| 55    | sstore         | [B             | slot[A] = 1     |
|
| 54    | sload          | [slot[B]       | read slot[B]    |
| 3d    | returndatasize | [slot[B], 0    |                 |
| 52    | mstore         | [              |                 |
|
| 6020  | push1 0x20     | [0x20          | return          |
| 3d    | returndatasize | [0x20, 0       |                 |
| f3    | return         |                |                 |
| ffff  |                |                |                 |


Runtime code bytes:
```
602435803D90553435469055543d5260203df3ffff
```

# deployment code

| bytes | Mnemonic       | Stack                | Comment                        |
| -     | -              | -                    | -                              |
| 6015  | push1 0x15     | [len                 | runtime_code.len == 0x15       |
| 80    | dup1           | [len, len            |                                |
| 600a  | push1 0a       | [len, len, offset    | runtime_code.offset == 0xa     |
| 3d    | returndatasize | [len, len, offset, 0 |                                |
| 39    | codecopy       | [len                 | copy runtime_code to memory[0] |
| 3d    | returndatasize | [len, 0              |                                |
| f3    | return         |                      |                                |
| ff    | invalid        |                      | add this byte to make rumtime offset to be `0x0a` instad of `9`, which is banned |


Deployment code bytes:
```
601580600a3d393df3ff
```

# The solution code 
`deployment code` + `runtime code` :
```
601580600a3d393df3ff602435803D90553435469055543d5260203df3ffff
(31 bytes)
```

# POC
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "forge-std/Test.sol";

contract EQ is Test {
    address isNumbersEQContract;
    bytes1[] badOpcodes;

    function setUp() public {
        badOpcodes.push(hex"01"); // ADD
        badOpcodes.push(hex"02"); // MUL
        badOpcodes.push(hex"03"); // SUB
        badOpcodes.push(hex"04"); // DIV
        badOpcodes.push(hex"05"); // SDIV
        badOpcodes.push(hex"06"); // MOD
        badOpcodes.push(hex"07"); // SMOD
        badOpcodes.push(hex"08"); // ADDMOD
        badOpcodes.push(hex"09"); // MULLMOD
        badOpcodes.push(hex"18"); // XOR
        badOpcodes.push(hex"10"); // LT
        badOpcodes.push(hex"11"); // GT
        badOpcodes.push(hex"12"); // SLT
        badOpcodes.push(hex"13"); // SGT
        badOpcodes.push(hex"14"); // EQ
        badOpcodes.push(hex"f0"); // create
        badOpcodes.push(hex"f5"); // create2
        badOpcodes.push(hex"19"); // NOT
        badOpcodes.push(hex"1b"); // SHL
        badOpcodes.push(hex"1c"); // SHR
        badOpcodes.push(hex"1d"); // SAR
        vm.createSelectFork(
            "https://rpc.ankr.com/eth"
        );
        address isNumbersEQContractTemp;
        // solution - your bytecode
        bytes
            memory bytecode = hex"601580600a3d393df3ff602435803D90553435469055543d5260203df3ffff"; // TODO:
        //
        require(bytecode.length < 40, "try harder!");
        for (uint i; i < bytecode.length; i++) {
            for (uint a; a < badOpcodes.length; a++) {
				if (bytecode[i] == badOpcodes[a]) revert();
            }
        }

        assembly {
            isNumbersEQContractTemp := create(
                0,
                add(bytecode, 0x20),
                mload(bytecode)
            )
            if iszero(extcodesize(isNumbersEQContractTemp)) {
                revert(0, 0)
            }
        }
        isNumbersEQContract = isNumbersEQContractTemp;
    }

    // fuzzing test
    function test_isNumbersEq(uint8 a, uint8 b) public {
        (bool success, bytes memory data) = isNumbersEQContract.call{value: 4}(
            abi.encodeWithSignature("isEq(uint256, uint256)", a, b)
        );
        require(success, "!success");
        uint result = abi.decode(data, (uint));
        a == b ? assert(result == 1) : assert(result != 1);

        // additional tests
        // 1 - equal numbers
        (, data) = isNumbersEQContract.call{value: 4}(
            abi.encodeWithSignature("isEq(uint256, uint256)", 57204, 57204)
        );
        require(abi.decode(data, (uint)) == 1, "1 test fail");
        // 2 - different numbers
        (, data) = isNumbersEQContract.call{value: 4}(
            abi.encodeWithSignature("isEq(uint256, uint256)", 0, 3568)
        );
        require(abi.decode(data, (uint)) != 1, "2 test fail");
    }
}

```

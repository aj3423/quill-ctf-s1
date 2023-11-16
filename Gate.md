# Analysis

- The challenge chooses function `f00000000_bvvvdlt` and `f00000001_grffjzz` because their signatures are simply '0' and '1', which saves a lot code bytes.
- The above '0'/'1' functions are required to return addresses, which can be implemented using storage variable. For function '0', return address at slot 0, and for function '1' return slot 1, this simplifies the logic and saves some bytes.
- The above addresses are passed in constructor, which doesn't increase runtime code size.
- To pass the `fail()` check, just `revert`.

# EVM bytes
## runtime code

| Bytes     | Mnemonic      | Stack                              | Comment                                   |
| ----      | ----          | ----                               | ----                                      |
| 6020      | PUSH1 20      | [0x20                              | Prepare for `return`                      |
| 6000      | PUSH1 0       | [0x20, 0                           |                                           |
| 80        | DUP1          | [0x20, 0, 0                        |                                           |
|           |               |                                    |                                           |
| 35        | CALLDATALOAD  | [0x20, 0, sig_32                   | get calling function signature            |
| 60E0      | PUSH1 0xE0    | [0x20, 0, sig_32, 0xE0             |                                           |
| 1C        | SHR           | [0x20, 0, sig_4                    |                                           |
| 80        | DUP1          | [0x20, 0, sig_4, sig_4             |                                           |
|           |               |                                    |                                           |
| 6001      | PUSH1 1       | [0x20, 0, sig_4, sig_4, 1          | If signature > 1, go to Fallback,         |
| 90        | SWAP1         | [0x20, 0, sig_4, 1, sig_4          | otherwise load corresponding storage slot |
| 11        | GT            | [0x20, 0, sig_4, sig_4>1           |                                           |
| 60XX      | PUSH Fallback | [0x20, 0, sig_4, sig_4>1, Fallback |                                           |
| 57        | JUMPI         | [0x20, 0, sig_4                    |                                           |
|           |               |                                    |                                           |
| 54        | SLOAD         | [0x20, 0, slot[sig_4]              | Load slot 0 or 1, return that address     |
| 6000      | PUSH1 0       | [0x20, 0, slot[sig_4], 0           |                                           |
| 52        | MSTORE        | [0x20, 0                           |                                           |
| F3        | RETURN        |                                    |                                           |
| Fallback: |               |                                    |                                           |
| 5B        | JUMPDEST      | [0x20, 0, sig_4                    | The Fallback, which handles the call      |
| 50        | POP1          | [0x20, 0                           | of `fail()`                               |
| FD        | REVERT        |                                    |                                           |

Total 25 bytes, satisfies the 33 byte limit:
> 60206000803560E01C806001901160155754600052F35B50FD

## deploy code

| Bytes | Mnemonic   | Stack              | Comment                              |
| ----  | ----       | ----               | ----                                 |
|       |            |                    | Init constructor with two args       |
| 6020  | PUSH1 20   | [0x20              |                                      |
| 60A0  | PUSH1 A0   | [0x20, A0          |                                      |
| 6000  | PUSH1 0    | [0x20, A0, 0       |                                      |
| 39    | CODECOPY   | [                  | memory[0] == Arg0                    |
| 6000  | PUSH1 0    | [0                 |                                      |
| 51    | MLOAD      | [Arg0              |                                      |
| 6000  | PUSH1 0    | [Arg0, 0           |                                      |
| 55    | SSTORE     | [                  | storage[0] = memory[0]               |
|       |            |                    |                                      |
| 6020  | PUSH1 20   | [0x20              |                                      |
| 60A1  | PUSH1 A1   | [0x20, A1          |                                      |
| 6000  | PUSH1 0    | [0x20, A0, 0       |                                      |
| 39    | CODECOPY   | [                  | memory[0] == Arg1                    |
| 6000  | PUSH1 0    | [0                 |                                      |
| 51    | MLOAD      | [Arg0              |                                      |
| 6001  | PUSH1 1    | [Arg0, 1           |                                      |
| 55    | SSTORE     | [                  | storage[1] = memory[0]               |
|       |            |                    |                                      |
|       |            |                    | copy runtime code                    |
| 6019  | PUSH1 0x19 | [0x19              | runtime code length: 25(0x19)        |
| 80    | DUP1       | [0x19, 0x19        |                                      |
| 60XX  | PUSH1 XX   | [0x19, 0x19, XX    | XX: runtime code offset: 37(0x25)    |
| 6000  | PUSH1 0    | [0x19, 0x19, XX, 0 |                                      |
| 39    | CODECOPY   | [0x19              | copy runtime code to memory[0]       |
|       |            |                    |                                      |
| 6000  | PUSH1 0    | [0x19, 0           |                                      |
| F3    | RETURN     |                    | return runtime code                  |

## The full bytes
The full bytes should be:
> deploy_code + runtime_code + constructor_arg0 + constructor_arg1


# POC (Hardhat)
AttackGate.js:
```javascript
const { ethers } = require('hardhat')
const { expect } = require('chai')

describe('[Challenge] Gate', function () {
	let deployer, attacker

	before(async function () {
		[deployer, attacker] = await ethers.getSigners()

		// Deploy
		this.gate = await (await ethers.getContractFactory('Gate', deployer)).deploy()
		expect(
			await this.gate.opened()
		).to.be.false
	})

	it('Exploit', async function () {

		var runtime_code = ethers.utils.hexlify(
			'0x60206000803560E01C806001901160155754600052F35B50FD'
		)
		var deploy_code = ethers.utils.hexlify(
			'0x6020603E6000396000516000556020605E60003960005160015560198060256000396000F3'
		)
		var bytes = ethers.utils.hexConcat([
			deploy_code,
			runtime_code,
			ethers.utils.zeroPad(this.gate.address, 32), // arg0 of constructor
			ethers.utils.zeroPad(attacker.address, 32) // arg1 of constructor
		])

		// deploy
		const abi = []
		const Contract = await ethers.getContractFactory(abi, bytes)
		this.solverContract = await Contract.deploy()

		// solve it
		await this.gate.connect(attacker).open(
			this.solverContract.address
		)
	})

	after(async function () {
		expect(
			await this.gate.opened()
		).to.be.true
	})
})


```

# Result

> $ npx hardhat test AttackGate.js
> 
> 
> [Challenge] Gate
> 
> ✔ Exploit
> 
> 
> 1 passing (810ms)

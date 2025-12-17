// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Proxy} from "@openzeppelin/contracts/proxy/Proxy.sol";

/**
 * @title SmallProxy - Minimal EIP-1967 Proxy Demo
 * @dev COMPLETE CLI WORKFLOW WITH FOUNDRY + ANVIL
 *
 * 1. anvil  (Terminal 1 - starts local chain @ http://127.0.0.1:8545)
 * 2. RPC_URL=http://127.0.0.1:8545
 *    save PRIVATE_KEY is in .env
 *
 * 3. forge create src/SmallProxy.sol:ImplementationA --rpc-url $RPC_URL --private-key $PRIVATE_KEY
 *    export IMPL_A=0x...  (save this address)
 *
 * 4. forge create src/SmallProxy.sol:SmallProxy --rpc-url $RPC_URL --private-key $PRIVATE_KEY
 *    export PROXY=0x...  (save this address)
 *
 * 5. cast send SmallProxy_Address "setImplementation(address)" $IMPL_A --rpc-url $RPC_URL --private-key $PRIVATE_KEY
 *
 * 6. VERIFY INITIAL STATE (should be 0):
 *    cast call SmallProxy_Address "readStorageSlot()(uint256)" --rpc-url $RPC_URL
 *
 * 7. SET VALUE THROUGH PROXY (hits fallback -> delegatecall -> ImplementationA.setValue):
 *    cast send SmallProxy_Address "setValue(uint256)" 42 --rpc-url $RPC_URL --private-key $PRIVATE_KEY
 *
 * 8. VERIFY STATE CHANGED IN PROXY STORAGE:
 *    cast call SmallProxy_Address "readStorageSlot()(uint256)" --rpc-url $RPC_URL   // Returns 42
 *    cast call ImplementationA "getValue()(uint256)" --rpc-url $RPC_URL          // Also returns 42
 *
 * KEY INSIGHT: s_value lives in PROXY's slot 0, not ImplementationA's storage.
 *              ImplementationA is just code executed via delegatecall in proxy context.
 */

// Deployed on anvil: 0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512
contract SmallProxy is Proxy {
    // EIP-1967 IMPLEMENTATION_SLOT (standard location for proxy impl address)
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    // ADMIN: Manually set implementation address in EIP-1967 slot
    function setImplementation(address newImplementation) public {
        assembly {
            sstore(_IMPLEMENTATION_SLOT, newImplementation)
        }
    }

    // OVERRIDE: OZ Proxy reads implementation from EIP-1967 slot
    function _implementation() internal view override returns (address impl) {
        assembly {
            impl := sload(_IMPLEMENTATION_SLOT)
        }
    }

    // HELPER: Builds calldata for ImplementationA.setValue()
    function getDataToTransact(uint256 _numberToUpdate) public pure returns (bytes memory) {
        return abi.encodeWithSignature("setValue(uint256)", _numberToUpdate);
    }

    // DEBUG: Direct read of PROXY's storage slot 0 (where s_value will live)
    function readStorageSlot() public view returns (uint256 slot0) {
        assembly {
            slot0 := sload(0)
        }
    }
}

// IMPLEMENTATION v1 - Storage layout: slot0 = s_value
// Deployed on avnil: 0x5FbDB2315678afecb367f032d93F642f64180aa3
contract ImplementationA {
    uint256 private s_value; // Maps to PROXY's slot 0 via delegatecall

    function setValue(uint256 _newValue) public {
        s_value = _newValue; // WRITES TO PROXY'S SLOT 0
    }

    function getValue() external view returns (uint256) {
        return s_value; // READS FROM PROXY'S SLOT 0
    }
}

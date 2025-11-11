# CrossBridgeMintDeltaTrap
## Overview

CrossBridgeMintDeltaTrap monitors bridged ERC‑20 tokens and detects anomalies when the token total supply exceeds the bridge’s locked balance beyond a configurable threshold (default 5% / 500 basis points). The trap is Drosera-compatible and enables automated alerts for unusual minting or bridge misaccounting.

This repository contains:

* `src/CrossBridgeMintDeltaTrap.sol` — main trap contract implementing `ITrap`.
* `src/CrossBridgeMintDeltaResponse.sol` — response contract handling alerts and logging reports.
* `drosera.toml` — sample Drosera configuration.
* `README.md` — this documentation and testing guide.

---

## Trap Logic & Behaviour

**State Variables**

* `address token` — ERC-20 token contract.
* `address bridge` — bridge contract managing locked tokens.
* `uint256 DEFAULT_THRESHOLD_BP` — anomaly threshold in basis points (500 = 5%).

**collect() Function**

* Reads `totalSupply` from the token contract.
* Reads `lockedBalance` from the bridge.
* Computes delta in basis points: `deltaBP = ((total - locked) * 10_000) / locked`.
* Marks `isAnomalous = true` if `deltaBP > DEFAULT_THRESHOLD_BP`.
* Returns encoded `BridgeSupplyData` struct:

  ```solidity
  struct BridgeSupplyData {
      address token;
      address bridge;
      uint256 totalSupply;
      uint256 lockedBalance;
      uint256 deltaBP;
      uint256 thresholdBP;
      uint256 timestamp;
      bool isAnomalous;
  }
  ```

**shouldRespond(bytes[] calldata data) Function**

* Decodes `BridgeSupplyData` from `data[0]`.
* If `isAnomalous` is true, returns `(true, abi.encode(MESSAGE, abi.encode(latest)))`.
* Otherwise returns `(false, bytes(""))`.

**Response Contract Behaviour**

* Emits `CrossBridgeMintAlert(token, bridge, deltaBP, thresholdBP, timestamp)`.
* Stores reports internally with `Report` struct.
* Events allow off-chain monitoring of anomalies.

---

## Deployment Steps

1. Compile contracts:

   ```bash
   forge build
   ```
2. Deploy `CrossBridgeMintDeltaResponse.sol` and note its address.
3. Deploy `CrossBridgeMintDeltaTrap.sol`.
4. Call `setAddresses(tokenAddress, bridgeAddress)` on the trap.
5. Update `drosera.toml` with `response_contract` and `whitelist`.
6. Run `drosera apply` to register the trap with a relay.

---

## Foundry Test / cast Examples

### 1) collect() Call

```bash
COLLECT_RAW=$(cast call --rpc-url <RPC_URL> <TRAP_ADDRESS> "collect()")
cast abi-decode "(address,address,uint256,uint256,uint256,uint256,uint256,bool)" "$COLLECT_RAW"
```

Decoded output:

* `token`, `bridge` addresses
* `totalSupply`, `lockedBalance`
* `deltaBP`, `thresholdBP`
* `timestamp`, `isAnomalous`

### 2) shouldRespond(bytes[]) via Foundry Script

Create `script/TestCrossBridgeMintDeltaTrap.s.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";

interface IBridgeMintDeltaTrap {
    function collect() external view returns (bytes memory);
    function shouldRespond(bytes[] calldata data) external pure returns (bool, bytes memory);
}

contract TestCrossBridgeMintDeltaTrap is Script {
    function run() external {
        string memory RPC = vm.envString("RPC_URL");
        address trap = vm.envAddress("TRAP_ADDRESS");

        IBridgeMintDeltaTrap t = IBridgeMintDeltaTrap(trap);
        bytes memory collected = t.collect();
        console.log("collect() raw:", toHexString(collected));

        (address token, address bridge, uint256 totalSupply, uint256 locked, uint256 deltaBP, uint256 thresholdBP, uint256 timestamp, bool anomalous) = abi.decode(collected, (address,address,uint256,uint256,uint256,uint256,uint256,bool));
        console.log("token:", toHexString(abi.encodePacked(token)));
        console.log("bridge:", toHexString(abi.encodePacked(bridge)));
        console.log("totalSupply:", totalSupply);
        console.log("locked:", locked);
        console.log("deltaBP:", deltaBP);
        console.log("thresholdBP:", thresholdBP);
        console.log("isAnomalous:", anomalous ? "true" : "false");

        bytes ;
        arr[0] = collected;

        (bool should, bytes memory payload) = t.shouldRespond(arr);
        console.log("shouldRespond ->", should ? "true" : "false");

        if (should) {
            (string memory msgText, bytes memory dataEncoded) = abi.decode(payload, (string, bytes));
            console.log("payload message:", msgText);
            console.log("payload encoded data length:", dataEncoded.length);
        }
    }

    function toHexString(bytes memory data) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < data.length; ++i) {
            str[2 + i*2] = alphabet[uint(uint8(data[i] >> 4))];
            str[3 + i*2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }
}
```

Run the script:

```bash
export RPC_URL="https://ethereum-hoodi-rpc.publicnode.com"
export TRAP_ADDRESS="0xYourTrapAddressHere"
forge script script/TestCrossBridgeMintDeltaTrap.s.sol:TestCrossBridgeMintDeltaTrap --rpc-url $RPC_URL --broadcast
```

### 3) Alternate cast-only Approach (Advanced)

```bash
DATA=$(cast abi-encode "(bytes)" "$COLLECT_RAW")
ARRAY=$(cast abi-encode "(bytes[])" "[$DATA]")
cast call --rpc-url <RPC_URL> <TRAP_ADDRESS> "shouldRespond(bytes[])" "$ARRAY"
```

---

## Purpose

Ensures on-chain token supply does not exceed locked bridge balances beyond safe limits. Detects mis-minting, bridge accounting errors, and potential exploits.

---

## Files

* `src/CrossBridgeMintDeltaTrap.sol` — main trap
* `src/CrossBridgeMintDeltaResponse.sol` — response contract
* `drosera.toml` — sample Drosera configuration
* `README.md` — this file

---

## Attribution

Repository inspected: Benedictjay/CrossBridgeMintDeltaTrap. ([GitHub][1])

# CrossBridgeMintDeltaTrap

# CrossBridgeMintDeltaTrap

## Overview

CrossBridgeMintDeltaTrap watches a bridged token’s supply vs locked balance on a designated bridge contract. If the on‑chain token total supply grows significantly beyond the bridge’s locked amount (exceeding a configurable threshold in basis points), the trap flags the situation as anomalous.
This repository contains:

* `src/CrossBridgeMintDeltaTrap.sol` — the trap contract implementing ITrap interface.
* `src/CrossBridgeMintDeltaResponse.sol` — the responder contract invoked when the trap triggers.
* `drosera.toml` — sample configuration for deployment in a Drosera / similar relay environment.
* `README.md` — this documentation and test instructions.

---

## Trap Logic & Behaviour

**State Variables**

* `address token` — ERC‑20 token contract whose total supply is monitored.
* `address bridge` — bridge contract address controlling locked token amounts.
* `uint256 thresholdBP` — threshold in basis points (1 basis point = 0.01 %) beyond which a delta triggers a response.
* `uint256 lastSnapshotSupply` — optional snapshot of last read total supply.
* `uint256 lastSnapshotLocked` — optional snapshot of last read locked balance.

**collect() Function**
When called (view mode):

1. Reads `uint256 totalSupply = IERC20(token).totalSupply()`.
2. Reads `uint256 locked = IBridge(bridge).lockedBalance(token)`.
3. Computes deltaBP = ( (totalSupply > locked) ? (totalSupply − locked) * 10,000 / locked : 0 ).
4. Compares deltaBP to `thresholdBP`.
5. Encodes the result into bytes:

   ````abi.encode(
       address token,
       address bridge,
       uint256 totalSupply,
       uint256 locked,
       uint256 deltaBP,
       uint256 thresholdBP,
       uint256 timestamp,
       bool isAnomalous
   )```
   ````
6. Returns that bytes payload.

**shouldRespond(bytes[] calldata data) Function**

* Expects `data.length ≥ 1`; uses `data[0]`.
* Decodes the payload returned by collect().
* If `isAnomalous == true`, returns `(true, abi.encode(address token, address bridge, uint256 deltaBP))`.
* Else returns `(false, bytes(""))`.
* This enables the relay or automated system to trigger the responder contract when anomaly detected.

**Response Contract Behaviour**
Upon invocation (by relay when `shouldRespond` indicates true):

* The responder emits an event **CrossBridgeMintAlert(token, bridge, deltaBP, timestamp)**.
* Optionally logs data for off‑chain monitoring or storage.

---

## Deployment Steps

1. Use `forge build` to compile contracts.
2. Deploy `CrossBridgeMintDeltaResponse.sol`. Note its address as `RESPONSE_CONTRACT_ADDRESS`.
3. Deploy `CrossBridgeMintDeltaTrap.sol`.
4. Call `setAddresses(tokenAddress, bridgeAddress)` on the trap contract.
5. Optionally call `setThresholdBP(value)` to adjust the basis‑point threshold.
6. Prepare `drosera.toml` like below and set:

   ```toml
   ethereum_rpc = "https://your‑rpc.endpoint"
   drosera_rpc = "https://relay.endpoint"
   eth_chain_id = <chain_id>

   [traps.crossbridge_mint_delta]
   path = "out/CrossBridgeMintDeltaTrap.sol/CrossBridgeMintDeltaTrap.json"
   response_contract = "0xRESPONSE_CONTRACT_ADDRESS"
   response_function = "respondWithCrossBridgeMintAlert(address,address,uint256)"
   cooldown_period_blocks = 100
   private_trap = true
   whitelist = ["YOUR_OPERATOR_ADDRESS"]
   ```

---

## Foundry Test / cast Examples

### 1) `collect()` Call (read‑only)

```bash
COLLECT_RAW=$(cast call --rpc-url <RPC_URL> <TRAP_ADDRESS> "collect()")
cast abi-decode "(address,address,uint256,uint256,uint256,uint256,uint256,bool)" "$COLLECT_RAW"
```

Example decoded output:

* token address: `0xToken…`
* bridge address: `0xBridge…`
* totalSupply: `1000000`
* locked: `900000`
* deltaBP: `1111` (i.e., ~11.11 %)
* thresholdBP: `500`
* timestamp: `1699999999`
* isAnomalous: `true`

Interpretation: Supply exceeds locked by ~11.11 % which is above the threshold of 5.00 % (500 bp), so trap marks anomaly.

### 2) `shouldRespond(bytes[])` Call

Using Foundry script is simpler; example script below.
Create file `script/TestCrossBridgeMintDeltaTrap.s.sol`:

```solidity
// SPDX‑License‑Identifier: MIT
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

        vm.broadcast();
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
            (address ptkn, address pbridge, uint256 pdeltaBP) = abi.decode(payload, (address,address,uint256));
            console.log("payload token:", toHexString(abi.encodePacked(ptkn)));
            console.log("payload bridge:", toHexString(abi.encodePacked(pbridge)));
            console.log("payload deltaBP:", pdeltaBP);
        }
    }

    function toHexString(bytes memory data) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(2 + data.length * 2);
        str[0] = "0";
        str[1] = "x";
        for (uint i = 0; i < data.length; ++i) {
            str[2 + i * 2] = alphabet[uint(uint8(data[i] >> 4))];
            str[3 + i * 2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }
}
```

#### Running the script

```bash
export RPC_URL="https://your‑rpc.endpoint"
export TRAP_ADDRESS="0xYourTrapAddressHere"

forge script script/TestCrossBridgeMintDeltaTrap.s.sol:TestCrossBridgeMintDeltaTrap --rpc-url $RPC_URL --broadcast
```

### 3) Alternate cast‑only approach (advanced)

If you want to skip Foundry script:

* First fetch `COLLECT_RAW`.
* Then encode array of bytes:

  ```bash
  DATA=$(cast abi-encode "(bytes)" "$COLLECT_RAW")
  ARRAY=$(cast abi-encode "(bytes[])" "[$DATA]")
  ```
* Call:

  ```bash
  cast call --rpc-url <RPC_URL> <TRAP_ADDRESS> "shouldRespond(bytes[])" "$ARRAY"
  ```
* Decode returned `(bool, bytes)` via `cast abi-decode`.

---

## Purpose

This trap adds a security layer for bridging systems. It ensures token supply growth beyond locked amounts does not go unnoticed. It helps expose minting bugs, mis‑accounting or malicious token inflation on bridge systems.

---

## Files

* `src/CrossBridgeMintDeltaTrap.sol` — main trap contract
* `src/CrossBridgeMintDeltaResponse.sol` — response contract
* `drosera.toml` — sample relay‑config
* `README.md` — this file

---

## Attribution

Repository inspected: Benedictjay/CrossBridgeMintDeltaTrap. ([GitHub][1])

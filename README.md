# CrossBridgeMintDeltaTrap
README — CrossBridgeMintDeltaTrap

Overview

This trap monitors a token that is bridged from another chain. It compares the token totalSupply with the amount locked in the bridge. If totalSupply grows faster than the locked amount, it signals a mint imbalance. This is a common failure case for bridges and wrapped tokens. The trap reports an anomaly when the excess supply passes a fixed threshold.

Trap Logic

The trap has two addresses:
token
bridge

The trap reads:
totalSupply from the token contract
lockedBalance from the bridge for that token

If totalSupply is greater than lockedBalance, it calculates a basis point difference. If the difference is greater than the threshold (default 5 percent), the trap marks the state as anomalous.

Collected State Format (encoded)
token
bridge
totalSupply
lockedBalance
deltaBP
thresholdBP
timestamp
isAnomalous

Response Behavior

shouldRespond checks the latest collected state. If isAnomalous is true, shouldRespond returns true and passes the encoded BridgeSupplyData and a human-readable message.

The CrossBridgeMintDeltaResponse contract receives the data and logs:
CrossBridgeMintAlert event for monitoring systems
ReportLogged event for indexing

It also stores each report in an internal array for later review.

Deployment Steps

1. Deploy CrossBridgeMintDeltaResponse.sol on-chain.

2. Deploy CrossBridgeMintDeltaTrap.sol.

3. Call setAddresses(token, bridge) on the trap.

4. Put the response contract address into drosera.toml:
   response_contract = "<address>"

5. Set whitelist in drosera.toml to the EOAs allowed to operate the trap.

6. Run:
   drosera apply

Dashboard and Sync will start once an operator is online and running.

Foundry Test Calls

Collect call
cast call <TRAP> "collect()"

Decode the return bytes
cast abi-decode "(address,address,uint256,uint256,uint256,uint256,uint256,bool)" <RETURN_DATA>

Check fields:
deltaBP > thresholdBP => anomaly

shouldRespond call
First encode collected output into bytes[]
DATA=$(cast abi-encode "(bytes)" <COLLECT_RETURN_DATA>)
ARRAY=$(cast abi-encode "(bytes[])" "[$DATA]")

Then call:
cast call <TRAP> "shouldRespond(bytes[])(bool,bytes)" "$ARRAY"

Expect:
true and payload if anomaly
false and empty bytes if normal

Response Test

To manually simulate Drosera calling the response contract:
cast send <RESPONSE> "respond(string,bytes)" "Cross-Bridge Delta" <ENCODED_BRIDGE_DATA>

Then inspect events:
cast logs --rpc-url <RPC> <RESPONSE>

Purpose

This trap provides continuous monitoring of bridge token supply integrity. It catches unauthorized minting, silent inflation, and bridge accounting failures early.

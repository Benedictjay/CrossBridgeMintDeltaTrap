// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ITrap} from "drosera-contracts/interfaces/ITrap.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
}

interface IBridge {
    function lockedBalance(address token) external view returns (uint256);
}

contract CrossBridgeMintDeltaTrap is ITrap {
    uint256 public constant DEFAULT_THRESHOLD_BP = 500; // 5% excess mint threshold

    address public token;
    address public bridge;

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

    string constant MESSAGE = "Cross-Bridge Mint Delta anomaly detected";

    constructor() {
        token = address(0);
        bridge = address(0);
    }

    /// @notice Set token and bridge addresses after deployment
    function setAddresses(address _token, address _bridge) external {
        require(_token != address(0), "Invalid token");
        require(_bridge != address(0), "Invalid bridge");
        token = _token;
        bridge = _bridge;
    }

    /// @notice Called periodically by Drosera to collect state
    function collect() external view override returns (bytes memory) {
        uint256 total = 0;
        uint256 locked = 0;

        if (token != address(0)) {
            try IERC20(token).totalSupply() returns (uint256 s) {
                total = s;
            } catch {}
        }

        if (bridge != address(0) && token != address(0)) {
            try IBridge(bridge).lockedBalance(token) returns (uint256 l) {
                locked = l;
            } catch {}
        }

        uint256 deltaBP = 0;
        bool isAnomaly = false;

        if (locked > 0 && total > locked) {
            deltaBP = ((total - locked) * 10_000) / locked;
            isAnomaly = deltaBP > DEFAULT_THRESHOLD_BP;
        }

        return abi.encode(
            BridgeSupplyData({
                token: token,
                bridge: bridge,
                totalSupply: total,
                lockedBalance: locked,
                deltaBP: deltaBP,
                thresholdBP: DEFAULT_THRESHOLD_BP,
                timestamp: block.timestamp,
                isAnomalous: isAnomaly
            })
        );
    }

    /// @notice Determines if Drosera should trigger a response
    function shouldRespond(bytes[] calldata data)
        external
        pure
        override
        returns (bool, bytes memory)
    {
        if (data.length == 0) return (false, bytes(""));

        BridgeSupplyData memory latest = abi.decode(data[0], (BridgeSupplyData));

        if (latest.isAnomalous) {
            return (true, abi.encode(MESSAGE, abi.encode(latest)));
        }

        return (false, bytes(""));
    }
}

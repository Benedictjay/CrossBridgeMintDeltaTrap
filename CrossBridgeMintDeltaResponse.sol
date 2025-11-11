// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CrossBridgeMintDeltaResponse {

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

    struct Report {
        BridgeSupplyData data;
        string message;
        uint256 id;
        address reporter;
    }

    event CrossBridgeMintAlert(
        address indexed token,
        address indexed bridge,
        uint256 deltaBP,
        uint256 thresholdBP,
        uint256 timestamp
    );

    event ReportLogged(
        uint256 indexed id,
        address indexed reporter,
        bytes encodedData,
        string message
    );

    uint256 public nextId = 1;
    Report[] public reports;
    mapping(address => uint256[]) public userReports;

    /// @notice Called by Drosera trap when anomaly detected
    function respond(string memory message, bytes calldata encodedData) external {
        BridgeSupplyData memory data = abi.decode(encodedData, (BridgeSupplyData));

        emit CrossBridgeMintAlert(
            data.token,
            data.bridge,
            data.deltaBP,
            data.thresholdBP,
            data.timestamp
        );

        Report memory r = Report({
            data: data,
            message: message,
            id: nextId++,
            reporter: msg.sender
        });

        reports.push(r);
        userReports[msg.sender].push(r.id);

        emit ReportLogged(r.id, msg.sender, encodedData, message);
    }

    function getReportsCount() external view returns (uint256) {
        return reports.length;
    }

    function getReport(uint256 id) external view returns (Report memory) {
        require(id < reports.length, "Invalid ID");
        return reports[id];
    }
}

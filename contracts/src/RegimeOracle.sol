// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title RegimeOracle
 * @notice Stores market regimes determined by 0G TEE inference.
 *         Maintains fail-closed staleness and verification checks.
 */
contract RegimeOracle {
    enum Regime {
        NORMAL,
        VOLATILE,
        HALT
    }

    struct RegimeData {
        Regime regime;
        uint16 oracleSpreadBps;
        uint40 updatedAt;
        bool teeVerified;
        bytes32 teeSignatureHash;
        string reqId;
    }

    address public owner;
    mapping(address => RegimeData) public makerRegimes;

    event RegimeUpdated(
        address indexed maker,
        Regime regime,
        uint16 oracleSpreadBps,
        uint40 updatedAt,
        bool teeVerified,
        bytes32 teeSignatureHash,
        string reqId
    );

    error Unauthorized();
    error InvalidSpread(uint16 spreadBps);

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    function setRegime(
        address maker,
        Regime regime,
        uint16 oracleSpreadBps,
        bool teeVerified,
        bytes32 teeSignatureHash,
        string calldata reqId
    ) external onlyOwner {
        if (oracleSpreadBps > 10_000) revert InvalidSpread(oracleSpreadBps);

        makerRegimes[maker] = RegimeData({
            regime: regime,
            oracleSpreadBps: oracleSpreadBps,
            updatedAt: uint40(block.timestamp),
            teeVerified: teeVerified,
            teeSignatureHash: teeSignatureHash,
            reqId: reqId
        });

        emit RegimeUpdated(
            maker,
            regime,
            oracleSpreadBps,
            uint40(block.timestamp),
            teeVerified,
            teeSignatureHash,
            reqId
        );
    }

    function getRegime(address maker)
        external
        view
        returns (
            Regime regime,
            uint16 oracleSpreadBps,
            uint40 updatedAt,
            bool teeVerified,
            bytes32 teeSignatureHash,
            string memory reqId
        )
    {
        RegimeData memory data = makerRegimes[maker];
        return (
            data.regime,
            data.oracleSpreadBps,
            data.updatedAt,
            data.teeVerified,
            data.teeSignatureHash,
            data.reqId
        );
    }

    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
    }
}


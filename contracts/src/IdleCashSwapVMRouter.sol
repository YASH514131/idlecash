// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { RegimeOracle } from "./RegimeOracle.sol";

// Interfaces matching official 1inch SwapVM
interface IAqua {
    function dock(address token, uint256 amount) external;
    function ship(address token, uint256 amount) external;
}

struct Query {
    address maker;
    address taker;
    address tokenIn;
    address tokenOut;
    uint256 amountIn;
    uint256 minAmountOut;
    bytes extraData;
}

struct VMState {
    uint256 amountIn;
    uint256 amountOut;
    uint256 flags;
}

struct Context {
    Query query;
    VMState vm;
}

struct Instruction {
    uint8 opcode;
    function(Context memory, bytes calldata) internal view handler;
}

/**
 * @title IdleCashSwapVMRouter
 * @notice Extends the official 1inch SwapVM with custom opcode 0x81 (OP_DYNAMIC_REGIME_SPREAD).
 *         Fails closed if oracle data is stale, unverified by 0G TEE, or if market is in HALT regime.
 */
contract IdleCashSwapVMRouter {
    uint8 public constant OP_DYNAMIC_REGIME_SPREAD = 0x81;
    IAqua public immutable aqua;
    RegimeOracle public immutable regimeOracle;

    error StrategyHaltedByAI(address maker, string zeroGRequestId);
    error StaleOracleData(uint40 updatedAt, uint40 currentTimestamp, uint32 maxStaleness);
    error UnverifiedOracleState(address maker);
    error InvalidBytecodeFormat();

    event StrategyHalted(address indexed maker, string zeroGRequestId);
    event DynamicSpreadApplied(address indexed maker, uint16 spreadBps, uint256 adjustedAmountIn);

    constructor(address _aqua, address _regimeOracle) {
        aqua = IAqua(_aqua);
        regimeOracle = RegimeOracle(_regimeOracle);
    }

    /**
     * @dev Official 1inch SwapVM extension hook.
     *      Appends custom Opcode 0x81 to the instruction set.
     */
    function _instructions() internal view virtual returns (Instruction[] memory res) {
        res = new Instruction[](1);
        res[0] = Instruction(OP_DYNAMIC_REGIME_SPREAD, _opDynamicRegimeSpread);
    }

    /**
     * @dev Custom Opcode 0x81: Reads RegimeOracle, fails closed if stale or halted, clamps spread
     *      to maker-signed [minSpreadBps, maxSpreadBps], and scales `ctx.vm.amountIn` before curve.
     *      Bytecode args (8 bytes):
     *      - [0:2] minSpreadBps (uint16)
     *      - [2:4] maxSpreadBps (uint16)
     *      - [4:8] maxStaleness (uint32)
     */
    function _opDynamicRegimeSpread(
        Context memory ctx,
        bytes calldata args
    ) internal view {
        if (args.length != 8) revert InvalidBytecodeFormat();

        uint16 minSpreadBps = uint16(bytes2(args[0:2]));
        uint16 maxSpreadBps = uint16(bytes2(args[2:4]));
        uint32 maxStaleness = uint32(bytes4(args[4:8]));

        (
            RegimeOracle.Regime regime,
            uint16 oracleSpreadBps,
            uint40 updatedAt,
            bool teeVerified,
            ,
            string memory reqId
        ) = regimeOracle.getRegime(ctx.query.maker);

        if (!teeVerified) {
            revert UnverifiedOracleState(ctx.query.maker);
        }

        if (block.timestamp > updatedAt + maxStaleness) {
            revert StaleOracleData(updatedAt, uint40(block.timestamp), maxStaleness);
        }

        if (regime == RegimeOracle.Regime.HALT) {
            revert StrategyHaltedByAI(ctx.query.maker, reqId);
        }

        uint256 activeSpreadBps = oracleSpreadBps;
        if (activeSpreadBps < minSpreadBps) activeSpreadBps = minSpreadBps;
        if (activeSpreadBps > maxSpreadBps) activeSpreadBps = maxSpreadBps;

        // Apply dynamic spread scale to prevent toxic arbitrage flow
        ctx.vm.amountIn = (ctx.vm.amountIn * (10_000 - activeSpreadBps)) / 10_000;
    }

    /**
     * @notice Simulates or executes an opcode step for testing / direct verification.
     */
    function executeOpcode(
        Context memory ctx,
        bytes calldata args
    ) external view returns (Context memory) {
        _opDynamicRegimeSpread(ctx, args);
        return ctx;
    }
}


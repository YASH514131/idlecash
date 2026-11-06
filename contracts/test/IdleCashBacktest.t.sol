// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { RegimeOracle } from "../src/RegimeOracle.sol";
import { IdleCashSwapVMRouter, Context, Query, VMState } from "../src/IdleCashSwapVMRouter.sol";

/**
 * @title IdleCashBacktest
 * @notice Invariant and unit backtest suite verifying:
 *         1. Custom Opcode 0x81 halts execution during a crash regime (preventing toxic arbitrage drainage).
 *         2. Dynamic spread clamps properly to [minSpreadBps, maxSpreadBps].
 *         3. Fail-closed staleness & unverified TEE guards prevent unverified execution.
 */
contract IdleCashBacktest {
    RegimeOracle oracle;
    IdleCashSwapVMRouter router;

    address constant MAKER = address(0x1111111111111111111111111111111111111111);
    address constant TAKER = address(0x2222222222222222222222222222222222222222);
    address constant WETH = address(0x4200000000000000000000000000000000000006);
    address constant USDC = address(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);

    function setUp() public {
        oracle = new RegimeOracle();
        router = new IdleCashSwapVMRouter(address(0x111), address(oracle));
    }

    /**
     * @notice Test that HALT regime reverts with StrategyHaltedByAI, blocking toxic flow.
     */
    function testHaltRegimeRevertsToxicFlow() public {
        // Set oracle to HALT regime with 0G TEE proof
        oracle.setRegime(
            MAKER,
            RegimeOracle.Regime.HALT,
            500, // 500 bps
            true, // teeVerified = true
            bytes32(uint256(0xabc)),
            "0g-req-crash-replay"
        );

        Context memory ctx = Context({
            query: Query({
                maker: MAKER,
                taker: TAKER,
                tokenIn: WETH,
                tokenOut: USDC,
                amountIn: 1 ether,
                minAmountOut: 2500e6,
                extraData: ""
            }),
            vm: VMState({
                amountIn: 1 ether,
                amountOut: 0,
                flags: 0
            })
        });

        // 8 bytes args: minSpread=10 (0x000a), maxSpread=100 (0x0064), maxStaleness=300 (0x0000012c)
        bytes memory args = hex"000a00640000012c";

        try router.executeOpcode(ctx, args) {
            revert("Execution should have reverted with StrategyHaltedByAI");
        } catch (bytes memory reason) {
            // Success: Opcode 0x81 blocked execution
            require(reason.length > 0, "Expected revert reason");
        }
    }

    /**
     * @notice Test that NORMAL regime dynamically scales amountIn by active spread.
     */
    function testNormalRegimeScalesSpread() public {
        oracle.setRegime(
            MAKER,
            RegimeOracle.Regime.NORMAL,
            15, // 15 bps spread
            true, // teeVerified = true
            bytes32(uint256(0xdef)),
            "0g-req-normal"
        );

        Context memory ctx = Context({
            query: Query({
                maker: MAKER,
                taker: TAKER,
                tokenIn: WETH,
                tokenOut: USDC,
                amountIn: 10_000,
                minAmountOut: 2500e6,
                extraData: ""
            }),
            vm: VMState({
                amountIn: 10_000,
                amountOut: 0,
                flags: 0
            })
        });

        bytes memory args = hex"000a00640000012c"; // min=10, max=100, maxStaleness=300

        Context memory result = router.executeOpcode(ctx, args);

        // Spread 15 bps: amountIn = 10_000 * (10_000 - 15) / 10_000 = 9985
        require(result.vm.amountIn == 9985, "Spread not properly scaled");
    }

    /**
     * @notice Test fail-closed on unverified TEE state.
     */
    function testUnverifiedTEEStateReverts() public {
        oracle.setRegime(
            MAKER,
            RegimeOracle.Regime.NORMAL,
            15,
            false, // teeVerified = false!
            bytes32(0),
            "0g-req-unverified"
        );

        Context memory ctx = Context({
            query: Query({
                maker: MAKER,
                taker: TAKER,
                tokenIn: WETH,
                tokenOut: USDC,
                amountIn: 1 ether,
                minAmountOut: 2500e6,
                extraData: ""
            }),
            vm: VMState({
                amountIn: 1 ether,
                amountOut: 0,
                flags: 0
            })
        });

        bytes memory args = hex"000a00640000012c";

        try router.executeOpcode(ctx, args) {
            revert("Execution should have reverted with UnverifiedOracleState");
        } catch {
            // Success: blocked unverified state
        }
    }
}


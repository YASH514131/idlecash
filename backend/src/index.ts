import express, { Request, Response } from "express";
import cors from "cors";
import { config } from "./config";
import {
  getAquaPosition,
  listAquaStrategies,
  prepareAquaDeposit,
  prepareAquaDock,
  verifyAquaTransaction,
  prepareAquaSwap,
  getAquaDeploymentStatus,
} from "./services/aqua";

const app = express();
app.use(cors());
app.use(express.json());

// Request Logger: Logs every incoming request clearly in terminal
app.use((req, _res, next) => {
  console.log(`\n📥 [${new Date().toLocaleTimeString()}] ${req.method} ${req.url}`);
  if (req.body && Object.keys(req.body).length > 0) {
    console.log(`   Payload:`, JSON.stringify(req.body));
  }
  next();
});

// Application Mode: "LIVE" or "DEMO"
const APP_MODE = process.env.APP_MODE || "DEMO";

// 1. Health & Mode Check
app.get("/health", (_req: Request, res: Response) => {
  res.json({
    status: "ok",
    service: "IdleCash Backend Relayer",
    version: "v3",
    mode: APP_MODE,
    timestamp: new Date().toISOString(),
    config: {
      baseRpc: config.rpc.baseSepolia,
    },
    protocols: {
      oneInchAqua: {
        status: "ship_dock_ready",
        description: "Official Aqua ship/dock calldata and multi-strategy registry",
      },
    },
  });
});

// ─── 1inch Aqua Protocol Endpoints ───────────────────────────────────────────

app.get("/api/aqua/status", async (_req: Request, res: Response) => {
  try {
    res.json(await getAquaDeploymentStatus("base_sepolia"));
  } catch (error) {
    res.status(503).json({
      ready: false,
      errors: [error instanceof Error ? error.message : "Aqua RPC is unavailable"],
    });
  }
});

// 9. 1inch Aqua Maker Position
app.get("/api/aqua/position", (req: Request, res: Response) => {
  const maker = (req.query.maker as string) || "0x71C8390b1c0628373b5e43A2338De3c3d5e939Ac";
  const pos = getAquaPosition(maker);
  res.json({
    ...pos,
    mode: APP_MODE,
  });
});

// 10. 1inch Aqua Deposit Intent
app.post("/api/aqua/deposit", (req: Request, res: Response) => {
  try {
    const { makerAddress, totalDepositUsd, wethAmount, usdcAmount, chain, spreadBps } = req.body;
    if (!makerAddress || !totalDepositUsd) return res.status(400).json({ error: "Missing makerAddress or totalDepositUsd." });
    res.json(prepareAquaDeposit({
      makerAddress,
      totalDepositUsd,
      wethAmount: wethAmount ?? (totalDepositUsd * 0.5) / 2600.0,
      usdcAmount: usdcAmount ?? totalDepositUsd * 0.5,
      chain: chain || "base_sepolia",
      spreadBps,
    }));
  } catch (error) {
    res.status(400).json({ error: error instanceof Error ? error.message : "Invalid Aqua strategy request" });
  }
});

// 11. Multi-strategy registry and wallet-signed dock transaction
app.get("/api/aqua/strategies", (req: Request, res: Response) => {
  res.json({ strategies: listAquaStrategies(req.query.maker as string | undefined) });
});

app.post("/api/aqua/dock", (req: Request, res: Response) => {
  try {
    const { makerAddress, strategyHash, chain = "base_sepolia", tokens } = req.body;
    res.json(prepareAquaDock(makerAddress, strategyHash, chain, tokens));
  } catch (error) {
    res.status(400).json({ error: error instanceof Error ? error.message : "Invalid Aqua dock request" });
  }
});

app.get("/api/aqua/verify", async (req: Request, res: Response) => {
  try {
    const txHash = req.query.txHash as string;
    const chain =
      (req.query.chain as "base_sepolia" | "base_mainnet") || "base_sepolia";
    if (!txHash) return res.status(400).json({ error: "Missing txHash." });
    res.json(await verifyAquaTransaction(txHash, chain));
  } catch (error) {
    res.status(400).json({
      error:
        error instanceof Error
          ? error.message
          : "Unable to verify Aqua transaction",
    });
  }
});

app.post("/api/aqua/swap/prepare", async (req: Request, res: Response) => {
  try {
    res.json(await prepareAquaSwap(req.body));
  } catch (error) {
    res.status(400).json({
      error:
        error instanceof Error
          ? error.message
          : "Unable to prepare Aqua swap",
    });
  }
});

// 12. SwapVM execution must be submitted by a taker wallet.
app.post("/api/aqua/swap", (req: Request, res: Response) => {
  res.status(501).json({
    error: "Aqua SwapVM execution is not simulated. Submit a signed taker order to the official AquaSwapVMRouter.",
    router: "0x111111338c5091e8440b67b168bae16a668ac0de",
  });
});

app.listen(config.port, () => {
  console.log(`IdleCash Backend running on port ${config.port} [Mode: ${APP_MODE}]`);
  console.log("1inch Aqua strategy endpoints ready.");
});

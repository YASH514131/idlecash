import {
  AquaProtocolContract,
  DockedEvent,
  PulledEvent,
  PushedEvent,
  ShippedEvent,
} from "@1inch/aqua-sdk";
import {
  AquaXYCAmmStrategy,
  MakerTraits,
  Order,
  SwapVMContract,
  SwappedEvent,
  TakerTraits,
} from "@1inch/swap-vm-sdk";
import { Address, HexString, type LogLike } from "@1inch/sdk-core";
import { config } from "../config";
import { decodeFunctionResult } from "viem";

export type AquaChain = "base_sepolia" | "base_mainnet";

export interface AquaStrategy {
  strategyId: string;
  strategyHash: string;
  strategy: string;
  makerAddress: string;
  appAddress: string;
  chain: AquaChain;
  tokens: { token: string; amount: string; decimals: number }[];
  spreadBps: number;
  createdAt: string;
  status: "active" | "docked";
  shipTxHash?: string;
  dockTxHash?: string;
}

export interface AquaPoolPosition {
  makerAddress: string;
  strategies: AquaStrategy[];
  totalLiquidityUsd: number;
  status: "active" | "halted";
}

export interface AquaDepositIntent {
  makerAddress: string;
  totalDepositUsd: number;
  wethAmount: number;
  usdcAmount: number;
  chain: AquaChain;
  spreadBps?: number;
}

export interface AquaDepositResult {
  success: boolean;
  strategy: AquaStrategy;
  transaction: { to: string; data: string; value: string };
  approval: { token: string; spender: string; amount: string }[];
  message: string;
}

function aquaAddress(chain: AquaChain): string {
  const address =
    chain === "base_mainnet" ? config.aqua.baseMainnet : config.aqua.baseSepolia;
  if (!address) {
    if (chain === "base_sepolia" && !config.localBaseFork) {
      throw new Error(
        "Aqua is not deployed on Base Sepolia. For local Aqua testing, restart the backend with LOCAL_BASE_FORK=true and LOCAL_BASE_FORK_RPC=http://127.0.0.1:8545.",
      );
    }
    throw new Error(
      `Aqua is not deployed/configured for ${chain}. Set ${chain === "base_mainnet" ? "BASE_MAINNET_AQUA" : "BASE_SEPOLIA_AQUA"} to the verified registry address.`,
    );
  }
  return assertAddress(address, "Aqua registry");
}
const SWAP_VM_ADDRESS = "0x111111338c5091e8440b67b168bae16a668ac0de";
const strategies = new Map<string, AquaStrategy>();

const eventParsers = [
  ["Shipped", ShippedEvent],
  ["Docked", DockedEvent],
  ["Pulled", PulledEvent],
  ["Pushed", PushedEvent],
] as const;

const swappedEventParser = ["Swapped", SwappedEvent] as const;

function serializeEvent(name: string, event: object) {
  return {
    name,
    ...Object.fromEntries(
      Object.entries(event).map(([key, value]) => [
        key,
        typeof value === "bigint" ? value.toString() : value.toString(),
      ]),
    ),
  };
}

export async function verifyAquaTransaction(txHash: string, chain: AquaChain) {
  if (!/^0x[0-9a-fA-F]{64}$/.test(txHash)) {
    throw new Error("txHash must be a 32-byte transaction hash");
  }
  const rpcUrl =
    chain === "base_mainnet" ? config.rpc.baseMainnet : config.rpc.baseSepolia;
  const expectedAquaAddress = aquaAddress(chain).toLowerCase();
  const response = await fetch(rpcUrl, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method: "eth_getTransactionReceipt",
      params: [txHash],
    }),
  });
  if (!response.ok) throw new Error(`RPC receipt request failed (${response.status})`);
  const body = (await response.json()) as {
    result?: {
      status?: string;
      to?: string;
      logs?: { address: string; data: `0x${string}`; topics: `0x${string}`[] }[];
    };
    error?: { message?: string };
  };
  if (body.error) throw new Error(body.error.message || "RPC receipt request failed");
  if (!body.result) return { confirmed: false, txHash, events: [] };
  if (body.result.status === "0x0") throw new Error("Transaction reverted on-chain");
  const contract = body.result.to?.toLowerCase();
  if (contract !== expectedAquaAddress) {
    throw new Error(
      `Transaction succeeded, but it targeted ${body.result.to || "an unknown contract"}, not the configured Aqua registry ${expectedAquaAddress}. Configure the verified ${chain} Aqua deployment before retrying.`,
    );
  }

  const events = [];
  for (const log of body.result.logs || []) {
    const aquaLog: LogLike = {
      data: log.data,
      topics: log.topics as [signature: `0x${string}`, ...`0x${string}`[]],
    };
    for (const [name, Parser] of [...eventParsers, swappedEventParser]) {
      if (aquaLog.topics[0]?.toLowerCase() !== Parser.TOPIC.toString().toLowerCase()) {
        continue;
      }

      events.push(serializeEvent(name, Parser.fromLog(aquaLog)));
      break;
    }
  }

  return {
    confirmed: true,
    txHash,
    contract: body.result.to,
    events,
    shipped: events.some((event) => event.name === "Shipped"),
    docked: events.some((event) => event.name === "Docked"),
    pulled: events.some((event) => event.name === "Pulled"),
    pushed: events.some((event) => event.name === "Pushed"),
  };
}

export async function getAquaDeploymentStatus(chain: AquaChain) {
  const rpcUrl =
    chain === "base_mainnet" ? config.rpc.baseMainnet : config.rpc.baseSepolia;
  const registry = aquaAddress(chain);
  const rpcChainId = await rpcCall(rpcUrl, "eth_chainId", []);
  const expectedChainId =
    config.localBaseFork && chain === "base_sepolia" ? "0x14a33" :
    chain === "base_mainnet" ? "0x2105" : "0x14a34";
  const [registryCode, routerCode] = await Promise.all([
    rpcCall(rpcUrl, "eth_getCode", [registry, "latest"]),
    rpcCall(rpcUrl, "eth_getCode", [SWAP_VM_ADDRESS, "latest"]),
  ]);
  const errors: string[] = [];
  if (rpcChainId.toLowerCase() !== expectedChainId) {
    errors.push(
      `RPC chain ID is ${rpcChainId}, expected ${expectedChainId} for ${chain}.`,
    );
  }
  if (registryCode === "0x") errors.push(`No Aqua registry bytecode at ${registry}.`);
  if (routerCode === "0x") errors.push(`No SwapVM router bytecode at ${SWAP_VM_ADDRESS}.`);
  return {
    ready: errors.length === 0,
    chain,
    localFork: config.localBaseFork,
    chainId: rpcChainId,
    registry,
    router: SWAP_VM_ADDRESS,
    errors,
  };
}

function assertAddress(value: string, name: string): string {
  if (!/^0x[0-9a-fA-F]{40}$/.test(value)) {
    throw new Error(`${name} must be a valid EVM address`);
  }

  return value;
}

async function rpcCall(rpcUrl: string, method: string, params: unknown[]) {
  const response = await fetch(rpcUrl, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
  });
  if (!response.ok) throw new Error(`RPC request failed (${response.status})`);
  const body = (await response.json()) as { result?: string; error?: { message?: string } };
  if (body.error) throw new Error(body.error.message || "RPC request failed");
  if (!body.result) throw new Error("RPC returned no result");
  return body.result;
}

export async function prepareAquaSwap(intent: {
  strategyHash: string;
  strategy: string;
  tokenIn: string;
  tokenOut: string;
  amountIn: string;
  chain: AquaChain;
}) {
  const rpcUrl =
    intent.chain === "base_mainnet" ? config.rpc.baseMainnet : config.rpc.baseSepolia;
  const order = Order.decode(new HexString(intent.strategy));
  const tokenIn = new Address(assertAddress(intent.tokenIn, "tokenIn"));
  const tokenOut = new Address(assertAddress(intent.tokenOut, "tokenOut"));
  const amountIn = BigInt(intent.amountIn);
  if (amountIn <= 0n) throw new Error("amountIn must be greater than zero");
  if (order.hash().toString().toLowerCase() !== intent.strategyHash.toLowerCase()) {
    throw new Error("strategyHash does not match the shipped strategy bytes");
  }

  const swapVM = new SwapVMContract(new Address(SWAP_VM_ADDRESS));
  const quoteCall = swapVM.quote({
    order,
    tokenIn,
    tokenOut,
    amount: amountIn,
    takerTraits: TakerTraits.default(),
  });
  const quoteResult = await rpcCall(rpcUrl, "eth_call", [
    { to: quoteCall.to, data: quoteCall.data },
    "latest",
  ]);
  const quote = decodeFunctionResult({
    abi: (await import("@1inch/swap-vm-sdk")).ABI.SWAP_VM_ABI,
    functionName: "quote",
    data: quoteResult as `0x${string}`,
  });
  const amountOut = quote[1];
  if (amountOut <= 0n) throw new Error("SwapVM quote returned zero output");

  const minAmountOut = (amountOut * 9_950n) / 10_000n;
  const swapCall = swapVM.swap({
    order,
    tokenIn,
    tokenOut,
    amount: amountIn,
    takerTraits: TakerTraits.default().with({ threshold: minAmountOut }),
  });
  return {
    quote: { amountIn: amountIn.toString(), amountOut: amountOut.toString() },
    transaction: {
      to: swapCall.to,
      data: swapCall.data,
      value: swapCall.value.toString(),
    },
    router: SWAP_VM_ADDRESS,
    strategyHash: intent.strategyHash,
  };
}

function chainTokens(chain: AquaChain) {
  if (chain === "base_mainnet" || config.localBaseFork) {
    return { weth: config.tokens.base.weth, usdc: config.tokens.base.usdc };
  }
  return {
    weth: process.env.BASE_SEPOLIA_WETH || "0x4200000000000000000000000000000000000006",
    usdc: process.env.BASE_SEPOLIA_USDC || "0x036CbD53842c5426634e7929541eC2318f3dCF7e",
  };
}

function amountUnits(amount: number, decimals: number, name: string): string {
  if (!Number.isFinite(amount) || amount <= 0) throw new Error(`${name} must be greater than zero`);
  return BigInt(Math.floor(amount * 10 ** decimals)).toString();
}

export function listAquaStrategies(makerAddress?: string): AquaStrategy[] {
  const maker = makerAddress?.toLowerCase();
  return [...strategies.values()].filter((item) => !maker || item.makerAddress.toLowerCase() === maker);
}

export function prepareAquaDeposit(intent: AquaDepositIntent): AquaDepositResult {
  const makerAddress = assertAddress(intent.makerAddress, "makerAddress");
  if (!["base_sepolia", "base_mainnet"].includes(intent.chain)) throw new Error("Unsupported Aqua chain");
  const spreadBps = intent.spreadBps ?? 15;
  if (!Number.isInteger(spreadBps) || spreadBps < 1 || spreadBps > 10_000) {
    throw new Error("spreadBps must be an integer between 1 and 10000");
  }

  const tokens = chainTokens(intent.chain);
  const weth = amountUnits(intent.wethAmount, 18, "wethAmount");
  const usdc = amountUnits(intent.usdcAmount, 6, "usdcAmount");
  const strategyProgram = AquaXYCAmmStrategy.new().withFeeTokenIn(spreadBps).withRandomSalt().build();
  const order = Order.new({ maker: new Address(makerAddress.toLowerCase()), traits: MakerTraits.default(), program: strategyProgram });
  const strategyBytes = order.encode();
  const strategyHash = order.hash();
  const transaction = AquaProtocolContract.buildShipTx(new Address(aquaAddress(intent.chain)), {
    app: new Address(SWAP_VM_ADDRESS),
    strategy: strategyBytes,
    amountsAndTokens: [
      { amount: BigInt(weth), token: new Address(tokens.weth) },
      { amount: BigInt(usdc), token: new Address(tokens.usdc) },
    ],
  });
  const strategy: AquaStrategy = {
    strategyId: strategyHash.toString(),
    strategyHash: strategyHash.toString(),
    strategy: strategyBytes.toString(),
    makerAddress,
    appAddress: SWAP_VM_ADDRESS,
    chain: intent.chain,
    tokens: [
      { token: tokens.weth, amount: weth, decimals: 18 },
      { token: tokens.usdc, amount: usdc, decimals: 6 },
    ],
    spreadBps,
    createdAt: new Date().toISOString(),
    status: "active",
  };
  strategies.set(`${makerAddress.toLowerCase()}:${strategyHash.toString()}`, strategy);

  return {
    success: true,
    strategy,
    transaction: { to: transaction.to, data: transaction.data, value: transaction.value.toString() },
    approval: [
      { token: tokens.weth, spender: aquaAddress(intent.chain), amount: weth },
      { token: tokens.usdc, spender: aquaAddress(intent.chain), amount: usdc },
    ],
    message: "Sign the ERC20 approvals and then the ship transaction with the connected maker wallet.",
  };
}

export function prepareAquaDock(
  makerAddress: string,
  strategyHash: string,
  chain: AquaChain,
  tokenAddresses?: string[],
) {
  const maker = assertAddress(makerAddress, "makerAddress").toLowerCase();
  if (!/^0x[0-9a-fA-F]{64}$/.test(strategyHash)) {
    throw new Error("strategyHash must be a 32-byte hash");
  }
  const knownStrategy = strategies.get(`${maker}:${strategyHash}`);
  if (knownStrategy && knownStrategy.chain !== chain) {
    throw new Error("Strategy chain does not match the requested chain");
  }
  const tokens = tokenAddresses?.length
    ? tokenAddresses.map((token, index) => new Address(assertAddress(token, `tokens[${index}]`)))
    : [new Address(chainTokens(chain).weth), new Address(chainTokens(chain).usdc)];
  if (tokens.length === 0) throw new Error("At least one strategy token is required");
  const transaction = AquaProtocolContract.buildDockTx(new Address(aquaAddress(chain)), {
    app: new Address(SWAP_VM_ADDRESS),
    strategyHash: new HexString(strategyHash),
    tokens,
  });
  if (knownStrategy) knownStrategy.status = "docked";
  return {
    transaction: {
      to: transaction.to,
      data: transaction.data,
      value: transaction.value.toString(),
    },
    strategy: knownStrategy,
  };
}

export function getAquaPosition(makerAddress: string): AquaPoolPosition {
  const makerStrategies = listAquaStrategies(makerAddress);
  return {
    makerAddress,
    strategies: makerStrategies,
    totalLiquidityUsd: makerStrategies.reduce((sum, item) => sum + Number(item.tokens[1].amount) / 1e6, 0),
    status: "active",
  };
}

export function executeAquaSwapVM(): never {
  throw new Error("Aqua SwapVM execution requires a signed taker transaction; no local simulation is returned.");
}

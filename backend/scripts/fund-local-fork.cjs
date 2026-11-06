const { encodeFunctionData, decodeFunctionResult } = require("viem");

const rpcUrl = process.env.LOCAL_BASE_FORK_RPC || "http://127.0.0.1:8545";
const account = process.env.LOCAL_FORK_ACCOUNT;
const amountUsdc = BigInt(process.env.LOCAL_FORK_USDC || "1000") * 1_000_000n;
const amountEth = BigInt(process.env.LOCAL_FORK_ETH || "10") * 10n ** 18n;

const weth = "0x4200000000000000000000000000000000000006";
const usdc = "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913";
const erc20Abi = [
  {
    type: "function",
    name: "balanceOf",
    stateMutability: "view",
    inputs: [{ name: "account", type: "address" }],
    outputs: [{ name: "balance", type: "uint256" }],
  },
  {
    type: "function",
    name: "transfer",
    stateMutability: "nonpayable",
    inputs: [
      { name: "to", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [{ name: "success", type: "bool" }],
  },
];
const usdcAbi = [
  {
    type: "function",
    name: "masterMinter",
    stateMutability: "view",
    inputs: [],
    outputs: [{ name: "minter", type: "address" }],
  },
  {
    type: "function",
    name: "configureMinter",
    stateMutability: "nonpayable",
    inputs: [
      { name: "minter", type: "address" },
      { name: "allowance", type: "uint256" },
    ],
    outputs: [{ name: "success", type: "bool" }],
  },
  {
    type: "function",
    name: "mint",
    stateMutability: "nonpayable",
    inputs: [
      { name: "to", type: "address" },
      { name: "amount", type: "uint256" },
    ],
    outputs: [],
  },
];

async function rpc(method, params = []) {
  const response = await fetch(rpcUrl, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method, params }),
  });
  const body = await response.json();
  if (body.error) throw new Error(`${method}: ${body.error.message || JSON.stringify(body.error)}`);
  return body.result;
}

function requireAddress(value, name) {
  if (!/^0x[0-9a-fA-F]{40}$/.test(value || "")) {
    throw new Error(`${name} must be a valid EVM address`);
  }
  return value;
}

async function send(from, to, data = "0x", value = "0x00") {
  const transaction = { from, to, data };
  if (value !== "0x00") transaction.value = value;
  let hash;
  try {
    hash = await rpc("eth_sendTransaction", [transaction]);
  } catch (error) {
    throw new Error(
      `send ${from} -> ${to} (${data.slice(0, 10)}): ${error.message}`,
    );
  }
  await waitForReceipt(hash);
  return hash;
}

async function waitForReceipt(hash) {
  for (let attempt = 0; attempt < 30; attempt += 1) {
    const receipt = await rpc("eth_getTransactionReceipt", [hash]);
    if (receipt) {
      if (receipt.status === "0x0") throw new Error(`Transaction reverted: ${hash}`);
      return receipt;
    }
    await new Promise((resolve) => setTimeout(resolve, 200));
  }
  throw new Error(`Timed out waiting for ${hash}`);
}

async function balance(token, owner) {
  const data = encodeFunctionData({
    abi: erc20Abi,
    functionName: "balanceOf",
    args: [owner],
  });
  const result = await rpc("eth_call", [{ to: token, data }, "latest"]);
  return decodeFunctionResult({
    abi: erc20Abi,
    functionName: "balanceOf",
    data: result,
  });
}

async function main() {
  const chainId = await rpc("eth_chainId");
  if (chainId !== "0x14a33") {
    throw new Error(`Expected local fork chain 84531 (0x14a33), received ${chainId}`);
  }
  const accounts = await rpc("eth_accounts");
  const target = requireAddress(account || accounts[0], "LOCAL_FORK_ACCOUNT");
  if (!accounts.some((item) => item.toLowerCase() === target.toLowerCase())) {
    throw new Error(
      `LOCAL_FORK_ACCOUNT is not a Ganache account. Use one of the accounts printed by Ganache.`,
    );
  }

  const ethHash = await send(
    target,
    weth,
    "0xd0e30db0",
    `0x${amountEth.toString(16)}`,
  );
  let usdcSource = "master-minter";
  const masterMinterData = encodeFunctionData({
    abi: usdcAbi,
    functionName: "masterMinter",
  });
  const masterMinterResult = await rpc("eth_call", [
    { to: usdc, data: masterMinterData },
    "latest",
  ]);
  const masterMinter = decodeFunctionResult({
    abi: usdcAbi,
    functionName: "masterMinter",
    data: masterMinterResult,
  });
  await rpc("evm_setAccountBalance", [
    masterMinter,
    "0x3635C9ADC5DEA000000000000000000000000000000000000000000000000",
  ]);
  const allowance = amountUsdc * 2n;
  const configureData = encodeFunctionData({
    abi: usdcAbi,
    functionName: "configureMinter",
    args: [target, allowance],
  });
  await send(masterMinter, usdc, configureData);

  const mintData = encodeFunctionData({
    abi: usdcAbi,
    functionName: "mint",
    args: [target, amountUsdc],
  });
  try {
    await send(target, usdc, mintData);
  } catch (error) {
    usdcSource = "existing-holder";
    throw new Error(
      `USDC master-minter funding failed after WETH funding. ${error.message}. Set up a known USDC holder only if this fork's USDC implementation does not expose the standard mint path.`,
    );
  }

  const ethBalance = BigInt(await rpc("eth_getBalance", [target, "latest"]));
  const wethBalance = await balance(weth, target);
  const usdcBalance = await balance(usdc, target);
  console.log(JSON.stringify({
    account: target,
    chainId: 84531,
    eth: (Number(ethBalance) / 1e18).toFixed(4),
    weth: (Number(wethBalance) / 1e18).toFixed(6),
    usdc: (Number(usdcBalance) / 1e6).toFixed(2),
    source: usdcSource,
    transactions: { wrapEth: ethHash },
  }, null, 2));
}

main().catch((error) => {
  console.error(`Local fork funding failed: ${error.message}`);
  process.exitCode = 1;
});

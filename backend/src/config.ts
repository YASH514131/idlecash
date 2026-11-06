import dotenv from "dotenv";
import path from "path";

// Load from backend/.env or root .env
dotenv.config({ path: path.resolve(__dirname, "../../.env") });
dotenv.config();

export const config = {
  port: process.env.PORT ? parseInt(process.env.PORT, 10) : 3001,
  rpc: {
    baseMainnet: process.env.BASE_MAINNET_RPC || "https://mainnet.base.org",
    baseSepolia: process.env.LOCAL_BASE_FORK_RPC || process.env.BASE_SEPOLIA_RPC || "https://sepolia.base.org",
  },
  localBaseFork: process.env.LOCAL_BASE_FORK === "true",
  aqua: {
    baseMainnet:
      process.env.BASE_MAINNET_AQUA ||
      "0x1111113ccf1426a8e30e2bff5e005d929bf6a90a",
    baseSepolia:
      process.env.LOCAL_BASE_FORK === "true"
        ? "0x1111113ccf1426a8e30e2bff5e005d929bf6a90a"
        : process.env.BASE_SEPOLIA_AQUA || "",
  },
  tokens: {
    base: {
      weth: "0x4200000000000000000000000000000000000006",
      usdc: "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    },
  },
};

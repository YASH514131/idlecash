const { spawn } = require("node:child_process");
const path = require("node:path");

const executable = path.resolve(
  __dirname,
  "..",
  "node_modules",
  "ts-node",
  "dist",
  "bin.js",
);
const child = spawn(
  process.execPath,
  [executable, "src/index.ts"],
  {
    cwd: path.resolve(__dirname, ".."),
    env: {
      ...process.env,
      LOCAL_BASE_FORK: "true",
      LOCAL_BASE_FORK_RPC:
        process.env.LOCAL_BASE_FORK_RPC || "http://127.0.0.1:8545",
    },
    stdio: "inherit",
    windowsHide: true,
  },
);

child.on("error", (error) => {
  console.error(`Could not start the fork backend: ${error.message}`);
  process.exitCode = 1;
});

for (const signal of ["SIGINT", "SIGTERM"]) {
  process.on(signal, () => child.kill(signal));
}

child.on("exit", (code) => {
  process.exitCode = code ?? 1;
});

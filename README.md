# IdleCash

**Self-custodial, multi-strategy liquidity management built around 1inch Aqua
and SwapVM.**

IdleCash is a Flutter wallet app and TypeScript API for creating, shipping,
checking, and docking Aqua strategies. The maker keeps control of the wallet:
the app prepares transactions, the connected wallet signs them, and the app
checks the resulting chain receipts before presenting a strategy as active.

> **Prototype notice:** This project is experimental and unaudited. Local-fork
> activity is not a mainnet transaction, test-token values are estimates, and
> the app does not currently calculate or claim realized Aqua fees.

## Our thesis: self-custodial shared liquidity

Liquidity providers should not have to hand custody of their assets to one
centralized platform in order to participate in market making. Centralized
custody can concentrate assets and operational control, creating
counterparty, access, and platform-security risks. IdleCash explores a
self-custodial alternative: each liquidity provider keeps assets in their own
wallet and authorizes strategy transactions themselves.

Our longer-term vision is for independent liquidity providers to make their
wallet-backed strategies available to a shared execution layer, with 1inch
Aqua and SwapVM as the strategy and routing building blocks. The goal is to
make liquidity contributed by multiple providers discoverable and usable
through compatible strategies, without IdleCash taking custody of the
providers' funds. IdleCash is intended to coordinate strategy setup and
visibility, not to become a custodial exchange or pooled account.

This is a product thesis, not a claim that the current app already pools
liquidity across different wallets. **Today, the app supports an individual
maker's wallet-signed Aqua ship/dock lifecycle and can track multiple
strategies for that maker.** A verified end-to-end taker swap, shared
execution across independent makers, and the associated production
operational controls remain future work.

Self-custody is not the same as being safe or risk-free. Users remain exposed
to smart-contract and wallet risks, malicious or incorrect transactions,
market and execution risk, lost keys, and network/RPC failures. Aqua, SwapVM,
and this prototype must not be described as guaranteeing protection against
loss. This project does not rely on an unsourced headline loss figure to make
that case; the motivation is the general custody and concentration risk of
centralized platforms.

## What is implemented

- **Wallet-signed Aqua ship lifecycle.** The backend uses the official 1inch
  Aqua and SwapVM SDKs to build a unique WETH/USDC strategy and prepare ERC-20
  approvals plus Aqua `ship()` calldata. The wallet signs each transaction.
- **Receipt-based verification.** The backend checks the transaction receipt,
  confirms the configured Aqua registry was called, and decodes recognized
  Aqua events. The app marks a strategy active only after confirming its
  `Shipped` event.
- **Multiple strategies per maker.** Strategy records are keyed by maker and
  strategy hash in the app. Each strategy has its own lifecycle, transaction
  hashes, token amounts, and verification details.
- **Wallet-signed dock lifecycle.** The app prepares Aqua `dock()` calldata,
  asks the wallet to sign, and verifies the `Docked` event. Docking removes
  Aqua's virtual strategy allocation; it is **not** a token withdrawal or a
  claim that funds were returned.
- **SwapVM quote and preparation.** `/api/aqua/swap/prepare` decodes the shipped
  strategy, requests an on-chain SwapVM quote, and prepares router calldata
  with a minimum-output threshold. This prepares a transaction; it does not
  sign or execute a swap.
- **Portfolio visibility.** Wallet token balances and Aqua strategy allocations
  are shown separately to avoid counting the same assets twice. The portfolio
  chart is local balance history, not yield or investment performance.
- **Persisted app state.** The wallet session, strategy records, and balance
  snapshots are saved on-device. Pending transactions are re-checked when the
  app restores saved state.

## Where the app actually uses 1inch Aqua

These are excerpts from the running backend and Flutter transaction flow, not
pseudocode. The complete implementations are in
[`backend/src/services/aqua.ts`](./backend/src/services/aqua.ts) and
[`frontend/lib/models/app_state.dart`](./frontend/lib/models/app_state.dart).

### 1. Build an Aqua strategy and official `ship()` calldata

In `prepareAquaDeposit`, the backend creates an Aqua XY=constant-product
market-making strategy, encodes it as an order, hashes it, and asks the Aqua
SDK to build the registry transaction:

```typescript
const strategyProgram = AquaXYCAmmStrategy.new()
  .withFeeTokenIn(spreadBps)
  .withRandomSalt()
  .build();
const order = Order.new({
  maker: new Address(makerAddress.toLowerCase()),
  traits: MakerTraits.default(),
  program: strategyProgram,
});
const strategyBytes = order.encode();
const strategyHash = order.hash();

const transaction = AquaProtocolContract.buildShipTx(
  new Address(aquaAddress(intent.chain)),
  {
    app: new Address(SWAP_VM_ADDRESS),
    strategy: strategyBytes,
    amountsAndTokens: [
      { amount: BigInt(weth), token: new Address(tokens.weth) },
      { amount: BigInt(usdc), token: new Address(tokens.usdc) },
    ],
  },
);
```

The backend returns this transaction and the required ERC-20 approvals to the
app; returning calldata does not itself execute or custody the transaction.

### 2. Ask the maker's wallet to sign, then verify the ship

Flutter sends the returned transaction through the connected wallet, waits for
its receipt, and checks for a verified Aqua `Shipped` event before activating
the strategy:

```dart
final shipHash = await WalletService.sendTransaction(
  to: transaction['to'] as String,
  data: transaction['data'] as String,
  value: transaction['value'] as String,
);
await WalletService.waitForReceipt(shipHash);
final verification = await _api.verifyAquaTransaction(txHash: shipHash);
if (verification['shipped'] != true) {
  throw StateError(
    'The ship transaction was confirmed, but Aqua did not emit Shipped.',
  );
}
strategy['status'] = 'active';
```

The two token approvals are requested and confirmed before this ship call.
The wallet remains the transaction signer; the backend prepares calldata and
checks the receipt.

### 3. Prepare the real Aqua `dock()` call

Docking is also built by the Aqua SDK using the maker's strategy hash and
tokens:

```typescript
const transaction = AquaProtocolContract.buildDockTx(
  new Address(aquaAddress(chain)),
  {
    app: new Address(SWAP_VM_ADDRESS),
    strategyHash: new HexString(strategyHash),
    tokens,
  },
);
```

The app asks the maker to sign the returned calldata and verifies the
`Docked` event. Docking removes Aqua's virtual strategy allocation; it does not
withdraw tokens into the wallet.

### What this code does not establish

These snippets show Aqua strategy registration and lifecycle transactions.
They do **not** show a completed taker swap, shared execution between
independent makers, or realized fee collection. The current SwapVM path can
quote a strategy and prepare slippage-limited calldata, but execution and
cross-wallet liquidity sharing remain future work.

## Transaction lifecycle

1. Connect the maker wallet on the selected network.
2. Choose a strategy size. The current UI configures the amount as a 50/50
   WETH/USDC allocation; token amounts are calculated using the displayed ETH
   spot estimate.
3. The app checks Aqua deployment readiness and requests a strategy from the
   backend. Each strategy receives its own random salt and hash.
4. The wallet signs the WETH approval, USDC approval, and Aqua `ship()`
   transaction. The app records the hashes and waits for receipts.
5. The backend verifies the ship receipt and event. Only then is the strategy
   shown as active.
6. To stop the virtual strategy, the maker signs Aqua `dock()`. The app checks
   the receipt and `Docked` event before updating its status.

**Important:** Shipping multiple strategies does not create separate wallet
balances or leverage. The strategies use the maker's wallet tokens and
allowances. Aqua strategy values are estimates based on recorded token amounts,
not independent balances held by IdleCash.

## Chart and portfolio data

The portfolio chart uses on-device snapshots written after successful wallet
balance refreshes. To avoid excessive history writes, another snapshot is
stored when the value changes materially (at least 0.1%) or when at least
15 minutes have passed since the previous snapshot. History is retained for up
to one year, subject to a 2,000-snapshot limit.

The chart now renders a neutral placeholder immediately, including before the
first sample. A trend line and percentage change require at least two snapshots;
refresh wallet balances to record another sample. Balance change includes
deposits and withdrawals and must not be interpreted as investment return.
WETH USD values use an ETH spot-price estimate, and Base Sepolia/local-fork
token USD values are not redeemable cash.

## Network and demo status

- **Local Base fork:** the tested development path uses Ganache forked from
  Base mainnet, chain ID `84531`, and the fork's copies of the Base Aqua and
  SwapVM contracts. Fork transactions are local and are not visible on Base
  explorers.
- **Base Sepolia:** the official Aqua SDK does not list an Aqua registry
  deployment on Base Sepolia. The backend fails closed unless a deployment is
  explicitly configured and verified. Do not configure an arbitrary address.
- **Base mainnet:** Aqua is listed by the SDK on Base mainnet (chain ID `8453`),
  but a live-mainnet user flow still needs its own deployment, wallet, and
  end-to-end verification before it should be presented as production-ready.
- **Swap execution:** strategy ship/dock verification is implemented. A
  successful taker SwapVM fill is a separate lifecycle and must not be inferred
  from quote preparation or ship/dock events.

## Contract addresses and on-chain components

The backend builds transactions for the official 1inch deployments below. The
addresses are chain-specific: a familiar address on one network does not prove
that the corresponding contract is deployed on another network.

| Component | Network | Address | How this project uses it |
|---|---|---|---|
| 1inch Aqua registry (`AquaRouter`) | Base mainnet (`8453`) | `0x1111113ccf1426a8e30e2bff5e005d929bf6a90a` | Registry target for SDK-generated `ship()` and `dock()` transactions; default backend configuration |
| 1inch AquaSwapVMRouter v1.0.2 | Base mainnet (`8453`) and local Base fork (`84531`) | `0x111111338c5091e8440b67b168bae16a668ac0de` | App address in the strategy and target `SwapVMContract` for quote/preparation |
| WETH | Base mainnet / local Base fork | `0x4200000000000000000000000000000000000006` | Strategy token and wallet balance |
| USDC | Base mainnet / local Base fork | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` | Strategy token and wallet balance |
| WETH | Base Sepolia configuration | `0x4200000000000000000000000000000000000006` | Configured by the frontend for testnet wallet reads; Aqua ship/dock remains disabled without a verified Aqua deployment |
| USDC | Base Sepolia configuration | `0x036CbD53842c5426634e7929541eC2318f3dCF7e` | Configured by the frontend for testnet wallet reads; Aqua ship/dock remains disabled without a verified Aqua deployment |

`84531` is a local Ganache chain ID used to fork Base mainnet; it is not Base
mainnet's chain ID (`8453`) and not Base Sepolia's (`84532`). On Base Sepolia,
`BASE_SEPOLIA_AQUA` is intentionally unset by default. The readiness check
fails closed rather than treating the Base mainnet registry address as a
verified testnet deployment.

### SDK contracts versus Solidity prototypes

The live app/backend Aqua path uses the official `@1inch/aqua-sdk` and
`@1inch/swap-vm-sdk` transaction builders and the deployments listed above.
This project does **not** deploy or call its own Solidity router as part of the
current ship/dock workflow.

The repository also contains two Solidity prototypes:

- [`contracts/src/IdleCashSwapVMRouter.sol`](./contracts/src/IdleCashSwapVMRouter.sol)
  defines a custom opcode, `OP_DYNAMIC_REGIME_SPREAD = 0x81`, that reads a
  `RegimeOracle` and adjusts or halts a swap. This is prototype code, is not
  registered with the official deployed SwapVM router, is not configured in
  the current backend, and must not be described as active protection.
- [`contracts/src/RegimeOracle.sol`](./contracts/src/RegimeOracle.sol) stores
  maker regime values for that custom-router prototype. It is not called by
  the current Aqua app flow, and no deployed address is configured for it.

Accordingly, **opcode `0x81` is not used by the current application**. The
active Aqua strategy uses the official SDK's `AquaXYCAmmStrategy` and the
official Aqua/SwapVM deployments; the custom regime opcode and oracle are
separate, undeployed prototype artifacts.

See [AQUA_INTEGRATION_README.md](./AQUA_INTEGRATION_README.md) for the detailed
network setup, contract addresses, local-fork funding steps, and integration
limitations. See [1inch_aqua.md](./1inch_aqua.md) for the project's 1inch
protocol research and design notes; distinguish those notes from the narrower
features currently implemented in this app.

## Architecture and file structure

```text
frontend/
  lib/
    models/
      app_state.dart          App state, strategy lifecycle, and portfolio data
    screens/
      main_nav_screen.dart    Main navigation
      home_screen.dart        Portfolio overview and strategy entry point
      create_strategy_screen.dart
      strategy_ready_screen.dart
      portfolio_screen.dart   Wallet assets, Aqua allocation, balance history
      activity_screen.dart
      settings_screen.dart
      wallet_connect_screen.dart
    services/
      api_service.dart        HTTP calls to the Aqua backend
      wallet_service.dart     Reown connection, wallet signing, RPC, persistence
    widgets/
      mini_chart.dart         Balance-history sparkline and empty-state chart
      donut_chart.dart
      token_icon.dart
      wallet_brand_logos.dart
    theme/
      app_theme.dart
  pubspec.yaml                Flutter dependencies and packaged assets

backend/
  src/
    index.ts                  Express health and Aqua API routes
    config.ts                 RPC, chain, and Aqua configuration
    services/
      aqua.ts                 Strategy encoding, ship/dock, SwapVM prep, receipts
  scripts/
    start-local-fork-backend.cjs
    fund-local-fork.cjs
  package.json                Build, local-fork, funding, and dev commands

contracts/
  src/                         Solidity prototypes (not the app's Aqua SDK path)
  test/                        Foundry prototype tests

AQUA_INTEGRATION_README.md     Detailed Aqua setup and integration notes
.env.example                  Backend environment template
work_need_to_do.md            Known remaining demo and release work
```

### Backend API

| Route | Purpose |
|---|---|
| `GET /health` | Backend mode, RPC, and Aqua protocol status |
| `GET /api/aqua/status` | Check expected chain ID and Aqua/SwapVM bytecode |
| `GET /api/aqua/position?maker=...` | List backend-known maker strategies |
| `POST /api/aqua/deposit` | Prepare a strategy, ERC-20 approvals, and ship calldata |
| `GET /api/aqua/strategies?maker=...` | List strategies currently known to the backend process |
| `POST /api/aqua/dock` | Prepare Aqua dock calldata |
| `GET /api/aqua/verify?txHash=...&chain=...` | Verify receipt and decode Aqua events |
| `POST /api/aqua/swap/prepare` | Quote and prepare a taker SwapVM transaction |
| `POST /api/aqua/swap` | Explicitly returns not-implemented for swap execution |

The backend strategy registry is in memory and is not the source of truth for
persisted mobile strategies. The app stores its own strategy records locally.

## Run and validate

### Flutter app

```powershell
cd frontend
flutter pub get
flutter run
```

For static analysis and an Android debug build:

```powershell
flutter analyze
flutter build apk --debug
```

### Backend

```powershell
cd backend
npm install
npm run build
npm run dev
```

### Local fork

The local workflow and wallet setup are documented step by step in
[AQUA_INTEGRATION_README.md](./AQUA_INTEGRATION_README.md). In brief, start
Ganache with `npm run fork:base`, fund a development account with
`npm run fund:fork`, and start the API with `npm run dev:fork`. Run the app with
the local-fork Dart defines from that guide. Use only a development account on
the local fork; never import a real wallet's private key into Ganache.


IdleCash is designed to make the transaction lifecycle and its limits visible:
the wallet signs, the chain receipt is checked, and unverified outcomes remain
unverified.

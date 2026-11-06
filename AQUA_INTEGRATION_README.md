# IdleCash 1inch Aqua / SwapVM Integration

## What is implemented

- Official `@1inch/aqua-sdk@0.4.0` and `@1inch/swap-vm-sdk@0.5.0` are installed in the backend.
- Strategy programs are created with the official `AquaXYCAmmStrategy`, `Order`, and `MakerTraits` SDK types.
- Each strategy receives a cryptographically random SDK salt, so two strategies with identical parameters have distinct `strategyHash` values.
- `/api/aqua/deposit` now prepares real wallet-signed ERC-20 approvals and an official Aqua `ship()` transaction. It does not fabricate a transaction hash or transfer custody.
- `/api/aqua/strategies` lists all strategies known by the backend, including multiple strategies for one maker.
- `/api/aqua/dock` prepares an official Aqua `dock()` transaction for a stored strategy.
- `/api/aqua/swap/prepare` decodes the shipped order, obtains an on-chain SwapVM quote, and prepares slippage-protected router calldata. Preparing calldata is not a swap execution.
- The Aqua manager does not present an unverified taker-swap demo. No fill or fee is reported unless an actual receipt is checked for its Aqua events.
- Flutter has API helpers for listing strategies and preparing a dock transaction.
- Flutter sends those transactions through the connected Reown WalletConnect session:
  - ERC-20 `approve()` for WETH and USDC
  - Aqua `ship()`
  - Aqua `dock()` through `AppState.dockAquaStrategy()`
- Strategy records, token addresses, proof events, and transaction hashes are persisted per maker on the device with SharedPreferences. Refreshing or restarting the app does not remove them.
- Dock preparation uses the locally saved strategy token list, so it does not depend on the backend's in-memory strategy registry surviving a restart.
- Selected-network receipt checks update local strategy status from `ship_pending`/`dock_pending` to `active`/`docked`.
- Ganache state is separate from app storage. Restarting Ganache resets its local chain and removes old local receipts; saved strategy records remain and are marked as missing fork state when that can be confirmed. They are not active liquidity on the new fork until a new strategy is shipped.
- Aqua `dock()` removes a strategy's virtual allocation. It does not withdraw tokens from Aqua or return funds; the maker's tokens remain in their wallet.
- After `ship()` confirmation, the backend checks that the receipt targeted the configured chain-specific Aqua registry and decodes the official Aqua SDK `Shipped` event. The Flutter flow only marks the strategy active after this event is verified.
- `GET /api/aqua/verify?txHash=...&chain=base_sepolia` exposes receipt and decoded `Shipped`, `Docked`, `Pulled`, `Pushed`, and other recognized Aqua events. The Aqua manager includes a manual transaction-hash verifier and shows verified strategy events.

## Official contracts and network support

The Aqua SDK lists the registry on Coinbase Base mainnet (`8453`). It does not list a Base Sepolia (`84532`) deployment. The same address must not be assumed to exist on testnet:

- Aqua registry: `0x1111113ccf1426a8e30e2bff5e005d929bf6a90a`
- AquaSwapVMRouter v1.0.2: `0x111111338c5091e8440b67b168bae16a668ac0de`

The backend therefore fails closed on Base Sepolia until a real compatible deployment is supplied through `BASE_SEPOLIA_AQUA`. Do not fill that variable with an arbitrary contract address. Base Sepolia can only be enabled after verifying bytecode, the `ship` ABI, and Aqua event topics on that chain.

## Wallet transaction flow

1. The connected maker calls `/api/aqua/deposit` with its address, chain, token amounts, and spread.
2. The backend returns two ERC-20 approval intents and `ship()` calldata.
3. The maker signs the approvals and the `ship()` call in the connected wallet.
4. The app stores the resulting transaction hashes and strategy hash.
5. To stop a strategy, the maker requests `/api/aqua/dock` and signs the returned transaction.
6. Tokens remain in the maker wallet. Aqua records virtual balances; it does not accept a token deposit.

Multiple strategies can be shipped for one maker. They share the maker's actual wallet balance and ERC-20 allowance. This is shared liquidity, not leverage.

## Local Base fork

The repository includes Ganache setup for a local fork of Base mainnet. This uses the
official Base Aqua and SwapVM addresses against forked state; transactions are local
and are not visible on Base explorers.

From `backend` in PowerShell:

```powershell
npm run fork:base
```

Copy one Ganache account address into `LOCAL_FORK_ACCOUNT`, then fund it:

```powershell
$env:LOCAL_FORK_ACCOUNT = "0x..."
$env:LOCAL_FORK_USDC = "1000"
$env:LOCAL_FORK_ETH = "10"
npm run fund:fork
```

The funding script wraps local ETH into Base WETH and uses the forked Base USDC
master-minter contract to create local USDC. It changes only the local fork.

In a second PowerShell window, start the backend in fork mode:

```powershell
$env:LOCAL_BASE_FORK_RPC = "http://127.0.0.1:8545"
npm run dev:fork
```

The app checks `/api/aqua/status` before sending approvals. This validates the
fork chain ID and that both official Aqua and SwapVM contracts have bytecode
before MetaMask is asked to sign. If setup is wrong, the strategy screen shows
the backend's specific error and leaves a retry action available.

Run Flutter for an Android emulator with:

```powershell
flutter run --dart-define=LOCAL_BASE_FORK=true --dart-define=LOCAL_BASE_FORK_RPC=http://10.0.2.2:8545
```

`LOCAL_BASE_FORK=true` is the default in Flutter debug builds. For a physical
Android phone, replace `10.0.2.2` with the PC's LAN IP and set the backend URL
as well:

```powershell
flutter run `
  --dart-define=LOCAL_BASE_FORK=true `
  --dart-define=LOCAL_BASE_FORK_RPC=http://192.168.1.25:8545 `
  --dart-define=BACKEND_URL=http://192.168.1.25:3001
```

Add the local network to MetaMask Mobile:

- Network name: `Local Base Fork`
- RPC URL: `http://10.0.2.2:8545`
- Chain ID: `84531` (local-only fork ID; Base mainnet is `8453`)
- Currency: `ETH`

Ganache prints funded development accounts and private keys. Import only a
development account into MetaMask; never use a real wallet key.

## Still required before claiming a complete live swap integration

- Submit and independently verify one genuine taker SwapVM transaction with `Swapped`, `Pulled`, and `Pushed` events. Strategy ship and dock receipts do not prove a taker fill.
- Obtain an official Base Sepolia Aqua/SwapVM deployment, or move the wallet flow to Base mainnet (`8453`) where the SDK lists Aqua.
- Verify the Aqua access-token requirement for the chosen taker/resolver.
- Add chain-specific contract/token configuration and deployment smoke tests.
- Replace hard-coded portfolio and activity values in Flutter with chain reads and strategy aggregation.

## Validation performed

- `npm run build` in `backend`: passed after the Aqua dock changes.
- Targeted `flutter analyze` on the changed Dart files: passed.
- Full `flutter analyze`: reports one unrelated existing unused-import warning in `lib/screens/settings_screen.dart`.
- No Flutter tests are present in `frontend/test`.
- No APK was built, per the previous request.

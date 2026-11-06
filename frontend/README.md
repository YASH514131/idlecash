# IdleCash frontend

## Android wallet connection

Wallet connection uses Reown AppKit (WalletConnect). It detects supported wallet
apps installed on Android, opens the wallet approval screen, and saves the
address only after the wallet approves the connection. No private key is
stored by the app.

The app includes its public Reown project ID, so it can be run normally. To
override it for another environment, run the frontend with a project ID:

```text
flutter run --dart-define=PROJECT_ID=your_reown_project_id
```

The app never creates a fake or randomly generated wallet address when using
the real connection flow.

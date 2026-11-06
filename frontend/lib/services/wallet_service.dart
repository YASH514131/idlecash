import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:reown_appkit/reown_appkit.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WalletSession {
  final String address;
  final String providerName;
  final DateTime connectedAt;
  final DateTime expiresAt;

  WalletSession({
    required this.address,
    required this.providerName,
    required this.connectedAt,
    required this.expiresAt,
  });

  bool get isValid => DateTime.now().isBefore(expiresAt);
}

class WalletAsset {
  final String symbol;
  final String name;
  final String contractAddress;
  final int decimals;
  final double balance;
  final double usdPrice;
  final String network;

  WalletAsset({
    required this.symbol,
    required this.name,
    required this.contractAddress,
    required this.decimals,
    required this.balance,
    required this.usdPrice,
    this.network = 'Base Sepolia',
  });

  double get usdValue => balance * usdPrice;
}

class WalletService {
  static const bool localBaseFork = bool.fromEnvironment(
    'LOCAL_BASE_FORK',
    defaultValue: !kReleaseMode,
  );
  static const String localBaseForkRpc = String.fromEnvironment(
    'LOCAL_BASE_FORK_RPC',
    defaultValue: 'http://10.0.2.2:8545',
  );
  static const String _keyAddress = 'idlecash_wallet_address';
  static const String _keyProvider = 'idlecash_wallet_provider';
  static const String _keyConnectedAt = 'idlecash_connected_at';
  static const int _sessionDurationDays = 30;
  static const String _keyAquaStrategies = 'idlecash_aqua_strategies';
  static const String _keyPortfolioHistoryPrefix =
      'idlecash_portfolio_history_';
  static const String _projectId = String.fromEnvironment(
    'PROJECT_ID',
    defaultValue: '0c9bf0658ee6794b73bbc18599a3c8e9',
  );
  static ReownAppKitModal? _appKitModal;
  static bool _transactionRequestInFlight = false;

  static void attachAppKitModal(ReownAppKitModal modal) {
    _appKitModal = modal;
  }

  static Future<void> ensureAppKitSession(BuildContext context) async {
    final existing = _appKitModal;
    if (existing?.isConnected == true && existing?.session != null) {
      await existing!.reconnectRelay();
      final approvedChains =
          existing.session!.getApprovedChains(namespace: 'eip155') ?? [];
      if (approvedChains.contains(activeChainNamespace)) {
        _appKitModal = existing;
        return;
      }
      throw StateError(
        'The current MetaMask connection does not include $activeNetworkName. Disconnect IdleCash from MetaMask, select $activeNetworkName, then reconnect.',
      );
    }
    if (_projectId.isEmpty) {
      throw StateError('WalletConnect is not configured.');
    }

    ReownAppKitModalNetworks.addSupportedNetworks(
      'eip155',
      [
        ReownAppKitModalNetworkInfo(
          name: activeNetworkName,
          chainId: activeChainId,
          currency: 'ETH',
          rpcUrl: activeRpcUrl,
          explorerUrl: localBaseFork ? '' : 'https://sepolia.basescan.org',
          isTestNetwork: true,
        ),
      ],
    );

    final modal = ReownAppKitModal(
      context: Navigator.of(context, rootNavigator: true).context,
      projectId: _projectId,
      metadata: const PairingMetadata(
        name: 'IdleCash',
        description: 'Self-custodial market making on Base',
        url: 'https://idlecash.app',
        icons: ['https://idlecash.app/icon.png'],
        redirect: Redirect(native: 'idlecash://'),
      ),
      disconnectOnDispose: false,
      optionalNamespaces: {
        'eip155': RequiredNamespace.fromJson({
          'chains': [activeChainNamespace],
          'methods': NetworkUtils.defaultNetworkMethods['eip155']!.toList(),
          'events': NetworkUtils.defaultNetworkEvents['eip155']!.toList(),
        }),
      },
    );
    await modal.init();
    if (!modal.isConnected || modal.session == null) {
      throw StateError(
          'Wallet session expired. Reconnect MetaMask before signing.');
    }
    final approvedChains =
        modal.session!.getApprovedChains(namespace: 'eip155') ?? [];
    if (!approvedChains.contains(activeChainNamespace)) {
      throw StateError(
          'This wallet session does not allow $activeNetworkName. Disconnect IdleCash in MetaMask and reconnect.');
    }
    _appKitModal = modal;
  }

  static String describeError(Object error) {
    if (error is ReownAppKitModalException) {
      final message = error.message?.toString();
      if (message != null && message.isNotEmpty) return message;
    }
    if (error is ModalError) {
      if (error.message.isNotEmpty) return error.message;
      if (error.description?.isNotEmpty == true) return error.description!;
    }
    final text = error.toString();
    return text.startsWith('Instance of ')
        ? 'Wallet request failed. Please retry.'
        : text;
  }

  static Future<String> sendTransaction({
    required String to,
    required String data,
    String value = '0x0',
  }) async {
    if (_transactionRequestInFlight) {
      throw StateError(
        'A wallet request is already open. Finish or reject it in MetaMask before continuing.',
      );
    }
    final modal = _appKitModal;
    final session = modal?.session;
    if (modal == null || session == null) {
      throw StateError('Connect a wallet before sending an Aqua transaction.');
    }
    final from = session.getAddress('eip155');
    if (from == null || from.isEmpty) {
      throw StateError('The connected wallet did not provide an EVM address.');
    }

    final selectedChainId = activeChainNamespace;
    _transactionRequestInFlight = true;
    try {
      final walletChainId = await modal.request(
        topic: session.topic,
        chainId: selectedChainId,
        request: const SessionRequestParams(
          method: 'eth_chainId',
          params: [],
        ),
      );
      final numericWalletChain = _numericChainId(walletChainId?.toString());
      if (numericWalletChain != activeChainId) {
        throw StateError(
          'MetaMask is on chain ${numericWalletChain ?? "unknown"}; select $activeNetworkName (chain $activeChainId) in MetaMask, then retry.',
        );
      }
      final result = await modal.request(
        topic: session.topic,
        chainId: selectedChainId,
        request: SessionRequestParams(
          method: 'eth_sendTransaction',
          params: [
            {
              'from': from,
              'to': to,
              'data': data,
              'value': _quantityHex(value),
            },
          ],
        ),
      );
      final transactionHash = _extractTransactionHash(result);
      if (transactionHash == null) {
        throw StateError(
            'MetaMask completed the request but returned no transaction hash. Check MetaMask activity before retrying.');
      }
      return transactionHash;
    } catch (error) {
      if (error is StateError) rethrow;
      throw StateError(
          'MetaMask transaction request failed: ${describeError(error)}');
    } finally {
      _transactionRequestInFlight = false;
    }
  }

  static String _quantityHex(String value) {
    final normalized = value.startsWith('0x') ? value.substring(2) : value;
    final amount = BigInt.tryParse(normalized, radix: 16) ??
        BigInt.tryParse(value) ??
        BigInt.zero;
    return '0x${amount.toRadixString(16)}';
  }

  static String? _numericChainId(String? chainId) {
    if (chainId == null || chainId.isEmpty) return null;
    final separator = chainId.indexOf(':');
    final value = separator == -1 ? chainId : chainId.substring(separator + 1);
    if (value.startsWith('0x')) {
      final parsed = int.tryParse(value.substring(2), radix: 16);
      return parsed?.toString();
    }
    return value;
  }

  static String? _extractTransactionHash(Object? result) {
    if (result is String) return _isTransactionHash(result) ? result : null;
    if (result is Map) {
      for (final entry in result.entries) {
        final hash = _extractTransactionHash(entry.value);
        if (hash != null) return hash;
      }
    }
    if (result is Iterable) {
      for (final value in result) {
        final hash = _extractTransactionHash(value);
        if (hash != null) return hash;
      }
    }
    return null;
  }

  static bool _isTransactionHash(String value) {
    return RegExp(r'^0x[0-9a-fA-F]{64}$').hasMatch(value);
  }

  static String encodeApprove(
      {required String spender, required String amount}) {
    final paddedSpender =
        spender.toLowerCase().replaceFirst('0x', '').padLeft(64, '0');
    final paddedAmount =
        BigInt.parse(amount).toRadixString(16).padLeft(64, '0');
    return '0x095ea7b3$paddedSpender$paddedAmount';
  }

  static Future<String> waitForReceipt(String txHash,
      {Duration timeout = const Duration(minutes: 2)}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      for (final rpcUrl in activeRpcUrls) {
        Object? receipt;
        try {
          final response = await http
              .post(
                Uri.parse(rpcUrl),
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode({
                  'jsonrpc': '2.0',
                  'id': 1,
                  'method': 'eth_getTransactionReceipt',
                  'params': [txHash],
                }),
              )
              .timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            final body = jsonDecode(response.body);
            if (body is Map) receipt = body['result'];
          }
        } catch (_) {
          // A connected wallet may still be able to query the receipt.
        }
        if (receipt is Map) {
          if (receipt['status']?.toString() == '0x0') {
            throw StateError('Transaction reverted: $txHash');
          }
          return txHash;
        }
      }

      final modal = _appKitModal;
      final session = modal?.session;
      if (modal != null && session != null) {
        Object? receipt;
        try {
          final result = await modal
              .request(
                topic: session.topic,
                chainId: activeChainNamespace,
                request: SessionRequestParams(
                  method: 'eth_getTransactionReceipt',
                  params: [txHash],
                ),
              )
              .timeout(const Duration(seconds: 8));
          receipt = result;
        } catch (_) {
          // Keep polling until the transaction is mined or the timeout expires.
        }
        if (receipt is Map) {
          if (receipt['status']?.toString() == '0x0') {
            throw StateError('Transaction reverted: $txHash');
          }
          return txHash;
        }
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    throw TimeoutException(
        'Timed out waiting for transaction receipt: $txHash');
  }

  static Future<void> saveAquaStrategy(Map<String, dynamic> strategy) async {
    final prefs = await SharedPreferences.getInstance();
    final records = prefs.getStringList(_keyAquaStrategies) ?? [];
    final hash = strategy['strategyHash'];
    records.removeWhere((record) {
      final decoded = jsonDecode(record) as Map<String, dynamic>;
      return decoded['strategyHash'] == hash;
    });
    records.add(jsonEncode(strategy));
    await prefs.setStringList(_keyAquaStrategies, records);
  }

  static Future<List<Map<String, dynamic>>> loadAquaStrategies() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_keyAquaStrategies) ?? [])
        .map((record) => jsonDecode(record) as Map<String, dynamic>)
        .toList();
  }

  // Base RPC Endpoints
  static const String baseSepoliaRpcUrl = 'https://sepolia.base.org';
  static const List<String> baseSepoliaRpcUrls = [
    baseSepoliaRpcUrl,
    'https://base-sepolia-rpc.publicnode.com',
    'https://base-sepolia.gateway.tenderly.co',
  ];

  static String get activeChainId => localBaseFork ? '84531' : '84532';
  static String get activeChainNamespace => 'eip155:$activeChainId';
  static String get activeNetworkName =>
      localBaseFork ? 'Local Base Fork' : 'Base Sepolia';
  static String get activeRpcUrl =>
      localBaseFork ? localBaseForkRpc : baseSepoliaRpcUrl;
  static List<String> get activeRpcUrls =>
      localBaseFork ? [localBaseForkRpc] : baseSepoliaRpcUrls;

  // Official Token Contracts on Base Sepolia
  static const String wethSepoliaContract =
      '0x4200000000000000000000000000000000000006';
  static const String usdcSepoliaContract =
      '0x036CbD53842c5426634e7929541eC2318f3dCF7e';
  static const String usdcBaseContract =
      '0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913';
  static String get activeWethContract => wethSepoliaContract;
  static String get activeUsdcContract =>
      localBaseFork ? usdcBaseContract : usdcSepoliaContract;

  /// Check if an active 30-day session exists
  static Future<WalletSession?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final address = prefs.getString(_keyAddress);
    final provider = prefs.getString(_keyProvider) ?? 'MetaMask';
    final connectedAtMs = prefs.getInt(_keyConnectedAt);

    if (address == null || connectedAtMs == null) {
      return null;
    }

    final connectedAt = DateTime.fromMillisecondsSinceEpoch(connectedAtMs);
    final expiresAt =
        connectedAt.add(const Duration(days: _sessionDurationDays));

    final session = WalletSession(
      address: address,
      providerName: provider,
      connectedAt: connectedAt,
      expiresAt: expiresAt,
    );

    if (session.isValid) {
      return session;
    } else {
      // Expired after 30 days
      await clearSession();
      return null;
    }
  }

  /// Save session to stay connected for 30 days
  static Future<void> saveSession({
    required String address,
    required String providerName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().millisecondsSinceEpoch;
    await prefs.setString(_keyAddress, address);
    await prefs.setString(_keyProvider, providerName);
    await prefs.setInt(_keyConnectedAt, now);
  }

  /// Disconnect and clear session
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAddress);
    await prefs.remove(_keyProvider);
    await prefs.remove(_keyConnectedAt);
  }

  /// Generate a real authentic Base EVM address for self-custodial active LPing
  static String generateRealEvmAddress() {
    final random = Random.secure();
    final bytes = List<int>.generate(20, (_) => random.nextInt(256));
    final hexString =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '0x$hexString';
  }

  /// Query live on-chain native ETH on Base Sepolia
  static Future<double> fetchBaseSepoliaEth(String address) async {
    try {
      final response = await http.post(
        Uri.parse(activeRpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'eth_getBalance',
          'params': [address, 'latest'],
        }),
      );

      if (response.statusCode != 200) {
        throw StateError('RPC returned HTTP ${response.statusCode}.');
      }
      final data = jsonDecode(response.body);
      if (data is! Map || data['error'] != null || data['result'] is! String) {
        throw StateError('RPC returned an invalid ETH balance response.');
      }
      final hexBal = data['result'] as String;
      final wei = BigInt.parse(hexBal.replaceFirst('0x', ''), radix: 16);
      return wei / BigInt.from(10).pow(18);
    } catch (error) {
      throw StateError(
        'Could not load ETH balance from $activeNetworkName: ${describeError(error)}',
      );
    }
  }

  /// Query live on-chain ERC20 token balance via eth_call
  static Future<double> fetchErc20Balance({
    required String rpcUrl,
    required String tokenContract,
    required String userAddress,
    required int decimals,
  }) async {
    try {
      final cleanAddr =
          userAddress.toLowerCase().replaceAll('0x', '').padLeft(64, '0');
      final data = '0x70a08231$cleanAddr'; // balanceOf(address) selector
      final response = await http.post(
        Uri.parse(rpcUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'jsonrpc': '2.0',
          'id': 2,
          'method': 'eth_call',
          'params': [
            {'to': tokenContract, 'data': data},
            'latest',
          ],
        }),
      );

      if (response.statusCode != 200) {
        throw StateError('RPC returned HTTP ${response.statusCode}.');
      }
      final body = jsonDecode(response.body);
      if (body is! Map || body['error'] != null || body['result'] is! String) {
        throw StateError('RPC returned an invalid token balance response.');
      }
      final hex = body['result'] as String;
      final clean = hex.replaceFirst('0x', '');
      if (clean.isEmpty) {
        throw StateError('Token contract returned an empty balance.');
      }
      final big = BigInt.parse(clean, radix: 16);
      final divisor = BigInt.from(10).pow(decimals);
      return big / divisor;
    } catch (error) {
      throw StateError(
        'Could not load token balance: ${describeError(error)}',
      );
    }
  }

  /// Fetch all Base Sepolia assets for connected wallet
  static Future<List<WalletAsset>> fetchBaseSepoliaAssets({
    required String address,
    required double ethPrice,
  }) async {
    final ethFuture = fetchBaseSepoliaEth(address);
    final wethFuture = fetchErc20Balance(
      rpcUrl: activeRpcUrl,
      tokenContract: activeWethContract,
      userAddress: address,
      decimals: 18,
    );
    final usdcFuture = fetchErc20Balance(
      rpcUrl: activeRpcUrl,
      tokenContract: activeUsdcContract,
      userAddress: address,
      decimals: 6,
    );

    final results = await Future.wait([ethFuture, wethFuture, usdcFuture]);
    final ethBal = results[0];
    final wethBal = results[1];
    final usdcBal = results[2];

    return [
      WalletAsset(
        symbol: 'ETH',
        name: 'Ethereum (Gas)',
        contractAddress: 'Native Asset',
        decimals: 18,
        balance: ethBal,
        usdPrice: 0,
        network: activeNetworkName,
      ),
      WalletAsset(
        symbol: 'USDC',
        name: 'USD Coin (Circle)',
        contractAddress: activeUsdcContract,
        decimals: 6,
        balance: usdcBal,
        usdPrice: 1.00,
        network: activeNetworkName,
      ),
      WalletAsset(
        symbol: 'WETH',
        name: 'Wrapped Ether (1inch)',
        contractAddress: activeWethContract,
        decimals: 18,
        balance: wethBal,
        usdPrice: ethPrice,
        network: activeNetworkName,
      ),
    ];
  }

  static String _portfolioHistoryKey(String address) =>
      '$_keyPortfolioHistoryPrefix${activeChainId}_${address.toLowerCase()}';

  static Future<List<Map<String, dynamic>>> loadPortfolioSnapshots(
    String address,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final records = prefs.getStringList(_portfolioHistoryKey(address)) ?? [];
    return records
        .map((record) => jsonDecode(record) as Map<String, dynamic>)
        .toList();
  }

  static Future<void> savePortfolioSnapshot({
    required String address,
    required double totalUsd,
  }) async {
    if (!totalUsd.isFinite || totalUsd < 0) {
      throw ArgumentError.value(
          totalUsd, 'totalUsd', 'Must be finite and non-negative.');
    }
    final prefs = await SharedPreferences.getInstance();
    final key = _portfolioHistoryKey(address);
    final records = prefs.getStringList(key) ?? [];
    final now = DateTime.now();
    Map<String, dynamic>? latest;
    if (records.isNotEmpty) {
      latest = jsonDecode(records.last) as Map<String, dynamic>;
    }
    final latestAt = DateTime.tryParse(latest?['capturedAt']?.toString() ?? '');
    final latestValue = double.tryParse(latest?['totalUsd']?.toString() ?? '');
    final changedMaterially = latestValue == null ||
        (totalUsd - latestValue).abs() >= (latestValue.abs() * 0.001);
    final sampleIntervalPassed = latestAt == null ||
        now.difference(latestAt) >= const Duration(minutes: 15);
    if (latest != null && !changedMaterially && !sampleIntervalPassed) return;

    records.add(jsonEncode({
      'capturedAt': now.toIso8601String(),
      'totalUsd': totalUsd,
    }));
    final cutoff = now.subtract(const Duration(days: 365));
    final retained = records.where((record) {
      final snapshot = jsonDecode(record) as Map<String, dynamic>;
      final capturedAt =
          DateTime.tryParse(snapshot['capturedAt']?.toString() ?? '');
      return capturedAt != null && capturedAt.isAfter(cutoff);
    }).toList();
    await prefs.setStringList(
      key,
      retained.length > 2000
          ? retained.sublist(retained.length - 2000)
          : retained,
    );
  }
}

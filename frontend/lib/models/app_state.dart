import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/wallet_service.dart';
import '../services/api_service.dart';

class ActivityItem {
  final String title;
  final String amount;
  final String time;
  final String type; // 'execution', 'fee', or 'update'
  final bool isPositive;
  final String source;

  ActivityItem({
    required this.title,
    required this.amount,
    required this.time,
    required this.type,
    this.isPositive = true,
    this.source = '1inch Aqua / Base',
  });
}

class PortfolioSnapshot {
  final DateTime capturedAt;
  final double totalUsd;

  const PortfolioSnapshot({
    required this.capturedAt,
    required this.totalUsd,
  });
}

enum AquaTransactionStatus {
  idle,
  preparing,
  signingWethApproval,
  confirmingWethApproval,
  signingUsdcApproval,
  confirmingUsdcApproval,
  signingShip,
  confirmingShip,
  signingDock,
  confirmingDock,
  complete,
  failed,
}

class AppState extends ChangeNotifier {
  final ApiService _api = ApiService();

  // App Execution Mode: "LIVE" vs "DEMO"
  String _appMode = 'DEMO';
  String get appMode => _appMode;

  void setAppMode(String mode) {
    _appMode = mode;
    notifyListeners();
  }

  // Navigation & Auth
  bool _isConnected = false;
  String? _walletAddress;
  String _walletProvider = 'MetaMask';
  DateTime? _sessionExpiresAt;
  bool _isSessionLoaded = false;
  int _currentTabIndex = 0;

  // Real Market & Portfolio State
  double _ethSpotPrice = 2631.57; // Live Base ETH/USDC spot
  double _totalPortfolioUsd = 0;

  double _strategyAmount = 500.0;
  double _maxSpread = 3.0;

  bool _isStrategyActive = false;
  double _activePositionUsd = 0;
  int _activeAllocationPercent = 0;

  // Connected Wallet Assets on Base Sepolia
  List<WalletAsset> _walletAssets = [];
  bool _isLoadingAssets = false;
  String? _walletAssetsError;
  List<PortfolioSnapshot> _portfolioSnapshots = [];
  String get selectedNetwork => WalletService.localBaseFork
      ? 'Local Base Fork (${WalletService.activeChainId})'
      : 'Base Sepolia (${WalletService.activeChainId})';
  List<Map<String, dynamic>> _aquaStrategies = [];
  List<Map<String, dynamic>> get aquaStrategies =>
      List.unmodifiable(_aquaStrategies);
  AquaTransactionStatus _aquaTransactionStatus = AquaTransactionStatus.idle;
  String? _aquaTransactionError;
  String? _aquaLastTransactionHash;
  String? _aquaVerificationStatus;
  AquaTransactionStatus get aquaTransactionStatus => _aquaTransactionStatus;
  String? get aquaTransactionError => _aquaTransactionError;
  String? get aquaLastTransactionHash => _aquaLastTransactionHash;
  String? get aquaVerificationStatus => _aquaVerificationStatus;

  void resetAquaTransaction() {
    _aquaTransactionStatus = AquaTransactionStatus.idle;
    _aquaTransactionError = null;
    _aquaLastTransactionHash = null;
    _aquaVerificationStatus = null;
    notifyListeners();
  }

  final List<ActivityItem> _activities = [];

  AppState() {
    _initSession();
    _fetchLiveSpotPrice();
  }

  /// Automatically restore persistent 30-day session on startup
  Future<void> _initSession() async {
    try {
      final session = await WalletService.loadSession();
      if (session != null && session.isValid) {
        _isConnected = true;
        _walletAddress = session.address;
        _walletProvider = session.providerName;
        _sessionExpiresAt = session.expiresAt;
        _portfolioSnapshots =
            (await WalletService.loadPortfolioSnapshots(session.address))
                .map(_portfolioSnapshotFromJson)
                .toList();
      }
      final savedStrategies = await WalletService.loadAquaStrategies();
      _aquaStrategies = _strategiesForCurrentWallet(savedStrategies);
      for (final strategy in _aquaStrategies) {
        if (strategy['status'] == 'dock_pending' &&
            strategy['dockTxHash'] is String) {
          try {
            final proof = await _api.verifyAquaTransaction(
              txHash: strategy['dockTxHash'] as String,
            );
            final events = proof['events'] as List<dynamic>? ?? const [];
            if (proof['confirmed'] == true &&
                events.any((event) => (event as Map)['name'] == 'Docked')) {
              strategy['status'] = 'docked';
              strategy['dockProofEvents'] = events;
              strategy['verifiedAt'] = DateTime.now().toIso8601String();
              await WalletService.saveAquaStrategy(strategy);
            }
          } catch (_) {
            // Keep the pending record visible while the RPC is offline.
          }
          continue;
        }
        if ((strategy['status'] != 'active' &&
                strategy['status'] != 'ship_pending') ||
            strategy['shipTxHash'] is! String) {
          continue;
        }
        try {
          final proof = await _api.verifyAquaTransaction(
            txHash: strategy['shipTxHash'] as String,
          );
          if (proof['confirmed'] == true && proof['shipped'] == true) {
            strategy['status'] = 'active';
            strategy['proofEvents'] = proof['events'];
            strategy['verifiedAt'] = DateTime.now().toIso8601String();
            await WalletService.saveAquaStrategy(strategy);
          } else if (strategy['status'] == 'active') {
            strategy['status'] = proof['confirmed'] == true
                ? 'verification_failed'
                : 'fork_state_missing';
            await WalletService.saveAquaStrategy(strategy);
          }
        } catch (_) {
          // Keep the locally persisted strategy visible while the RPC is offline.
        }
      }
      _refreshAquaSummary();
      if (_isConnected) refreshWalletAssets();
    } finally {
      _isSessionLoaded = true;
      notifyListeners();
    }
  }

  List<Map<String, dynamic>> _strategiesForCurrentWallet(
    List<Map<String, dynamic>> strategies,
  ) {
    final address = _walletAddress?.toLowerCase();
    if (address == null) return [];
    return strategies
        .where(
            (item) => item['makerAddress']?.toString().toLowerCase() == address)
        .toList();
  }

  void _refreshAquaSummary() {
    final active = _aquaStrategies
        .where((strategy) => strategy['status'] == 'active')
        .toList();
    _isStrategyActive = active.isNotEmpty;
    _activePositionUsd = active.fold<double>(
      0,
      (total, strategy) => total + _strategyLiquidityUsd(strategy),
    );
    _activeAllocationPercent = _calculateAllocationPercent(
      _activePositionUsd,
      minimum: 0,
    );
  }

  double _strategyLiquidityUsd(Map<String, dynamic> strategy) {
    final tokens = (strategy['tokens'] as List<dynamic>? ?? const []);
    var total = 0.0;
    for (final rawToken in tokens) {
      if (rawToken is! Map) continue;
      final amount = double.tryParse(rawToken['amount']?.toString() ?? '');
      final decimals = int.tryParse(rawToken['decimals']?.toString() ?? '');
      if (amount == null || decimals == null || decimals < 0) continue;
      final normalized = amount / math.pow(10, decimals);
      final address = rawToken['token']?.toString().toLowerCase();
      total += address == WalletService.activeWethContract.toLowerCase()
          ? normalized * _ethSpotPrice
          : normalized;
    }
    return total;
  }

  double aquaStrategyLiquidityUsd(Map<String, dynamic> strategy) =>
      _strategyLiquidityUsd(strategy);

  double aquaStrategyConfiguredAmount(Map<String, dynamic> strategy) {
    final configured = double.tryParse(
      strategy['configuredAmountUsd']?.toString() ?? '',
    );
    final amount = configured ?? _strategyLiquidityUsd(strategy) / 0.75;
    return amount.clamp(50, 2000).toDouble();
  }

  /// Fetch live real-time ETH spot price
  Future<void> _fetchLiveSpotPrice() async {
    try {
      final res = await http
          .get(Uri.parse('https://api.coinbase.com/v2/prices/ETH-USD/spot'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final price =
            double.tryParse(data['data']?['amount']?.toString() ?? '');
        if (price != null && price > 0) {
          _ethSpotPrice = price;
          _refreshAquaSummary();
          notifyListeners();
          if (_isConnected) unawaited(refreshWalletAssets());
        }
      }
    } catch (_) {}
  }

  // Getters
  bool get isConnected => _isConnected;
  bool get isSessionLoaded => _isSessionLoaded;
  String? get walletAddress => _walletAddress;
  String get walletProvider => _walletProvider;
  DateTime? get sessionExpiresAt => _sessionExpiresAt;
  int get currentTabIndex => _currentTabIndex;

  int get sessionDaysRemaining {
    if (_sessionExpiresAt == null) return 30;
    final diff = _sessionExpiresAt!.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  double get ethSpotPrice => _ethSpotPrice;
  double get totalPortfolioUsd => _totalPortfolioUsd;
  double? get portfolioChangePercent {
    if (_portfolioSnapshots.length < 2) return null;
    final first = _portfolioSnapshots.first.totalUsd;
    final last = _portfolioSnapshots.last.totalUsd;
    if (first <= 0) return null;
    return ((last - first) / first) * 100;
  }

  double get strategyAmount => _strategyAmount;
  double get strategyWeth => newStrategyWethAmount;

  int _calculateAllocationPercent(
    double positionUsd, {
    required int minimum,
  }) {
    if (!positionUsd.isFinite ||
        !_totalPortfolioUsd.isFinite ||
        _totalPortfolioUsd <= 0) {
      return 0;
    }
    return ((positionUsd / _totalPortfolioUsd) * 100)
        .round()
        .clamp(minimum, 100);
  }

  double get maxSpread => _maxSpread;

  bool get isStrategyActive => _isStrategyActive;
  double get activePositionUsd => _activePositionUsd;
  int get activeAllocationPercent => _activeAllocationPercent;

  List<ActivityItem> get activities => _activities;

  // Wallet Assets (Base Sepolia)
  List<WalletAsset> get walletAssets => _walletAssets;
  bool get isLoadingAssets => _isLoadingAssets;
  String? get walletAssetsError => _walletAssetsError;
  List<PortfolioSnapshot> get portfolioSnapshots =>
      List.unmodifiable(_portfolioSnapshots);
  double get walletAssetsTotalUsd =>
      _walletAssets.fold(0.0, (sum, a) => sum + a.usdValue);
  double get portfolioWethPercent {
    final total = walletAssets
        .where((asset) => asset.symbol == 'WETH' || asset.symbol == 'USDC')
        .fold<double>(0, (sum, asset) => sum + asset.usdValue);
    if (total <= 0) return 0;
    final weth = _walletAssets
        .where((asset) => asset.symbol == 'WETH')
        .fold(0.0, (sum, asset) => sum + asset.usdValue);
    return (weth / total * 100).roundToDouble();
  }

  double get portfolioUsdcPercent =>
      (100 - portfolioWethPercent).clamp(0.0, 100.0).toDouble();

  double get aquaStrategyUsd => _strategyAmount;
  double get newStrategyWethAmount => (_strategyAmount * 0.5) / _ethSpotPrice;
  double get newStrategyUsdcAmount => _strategyAmount * 0.5;

  // 1inch Aqua Protocol State
  double get aquaFeesEarnedUsd => 0;
  List<Map<String, dynamic>> get activeAquaStrategies => _aquaStrategies
      .where((strategy) => strategy['status'] == 'active')
      .toList(growable: false);
  double get aquaTotalLiquidityUsd => activeAquaStrategies.fold<double>(
        0,
        (total, strategy) => total + _strategyLiquidityUsd(strategy),
      );
  double get aquaDockedStrategyValueUsd => _aquaStrategies
      .where((strategy) => strategy['status'] == 'docked')
      .fold<double>(
        0,
        (total, strategy) => total + _strategyLiquidityUsd(strategy),
      );
  double get aquaWethLiquidity => _sumStrategyTokenAmount(
        activeAquaStrategies,
        WalletService.activeWethContract,
      );
  double get aquaUsdcLiquidity => _sumStrategyTokenAmount(
        activeAquaStrategies,
        WalletService.activeUsdcContract,
      );

  double _sumStrategyTokenAmount(
    List<Map<String, dynamic>> strategies,
    String tokenAddress,
  ) {
    var total = 0.0;
    for (final strategy in strategies) {
      for (final rawToken
          in (strategy['tokens'] as List<dynamic>? ?? const [])) {
        if (rawToken is! Map ||
            rawToken['token']?.toString().toLowerCase() !=
                tokenAddress.toLowerCase()) {
          continue;
        }
        final amount = double.tryParse(rawToken['amount']?.toString() ?? '');
        final decimals = int.tryParse(rawToken['decimals']?.toString() ?? '');
        if (amount != null && decimals != null && decimals >= 0) {
          total += amount / math.pow(10, decimals);
        }
      }
    }
    return total;
  }

  // ─── 1inch Aqua Deposit ────────────────────────────────────────────────────

  Future<void> depositTo1inchAqua() async {
    final addr = _walletAddress;
    if (addr == null) {
      throw StateError('Connect a wallet before creating an Aqua strategy.');
    }

    try {
      _aquaTransactionStatus = AquaTransactionStatus.preparing;
      _aquaTransactionError = null;
      notifyListeners();
      await _api.getAquaDeploymentStatus();
      final prepared = await _api.prepareAquaDeposit(
        makerAddress: addr,
        totalDepositUsd: aquaStrategyUsd,
        wethAmount: newStrategyWethAmount,
        usdcAmount: newStrategyUsdcAmount,
      );
      final strategy = Map<String, dynamic>.from(prepared['strategy'] as Map);
      strategy['status'] = 'preparing';
      strategy['shipTxHash'] = null;
      strategy['configuredAmountUsd'] = _strategyAmount;
      await WalletService.saveAquaStrategy(strategy);
      _upsertAquaStrategy(strategy);
      final approvals =
          (prepared['approval'] as List<dynamic>).cast<Map<String, dynamic>>();
      final transaction =
          Map<String, dynamic>.from(prepared['transaction'] as Map);

      for (final approval in approvals) {
        _aquaTransactionStatus =
            approval['token'] == WalletService.activeWethContract
                ? AquaTransactionStatus.signingWethApproval
                : AquaTransactionStatus.signingUsdcApproval;
        notifyListeners();
        final approvalHash = await WalletService.sendTransaction(
          to: approval['token'] as String,
          data: WalletService.encodeApprove(
            spender: approval['spender'] as String,
            amount: approval['amount'] as String,
          ),
        );
        strategy['status'] = 'approving';
        strategy['approvalTxHashes'] ??= <String>[];
        (strategy['approvalTxHashes'] as List).add(approvalHash);
        await WalletService.saveAquaStrategy(strategy);
        _upsertAquaStrategy(strategy);
        _aquaLastTransactionHash = approvalHash;
        notifyListeners();
        _aquaTransactionStatus =
            approval['token'] == WalletService.activeWethContract
                ? AquaTransactionStatus.confirmingWethApproval
                : AquaTransactionStatus.confirmingUsdcApproval;
        notifyListeners();
        await WalletService.waitForReceipt(approvalHash);
        strategy['approvalTxHash:${approval['token']}'] = approvalHash;
      }

      _aquaTransactionStatus = AquaTransactionStatus.signingShip;
      notifyListeners();
      final shipHash = await WalletService.sendTransaction(
        to: transaction['to'] as String,
        data: transaction['data'] as String,
        value: transaction['value'] as String,
      );
      _aquaLastTransactionHash = shipHash;
      notifyListeners();
      strategy['shipTxHash'] = shipHash;
      strategy['status'] = 'ship_pending';
      await WalletService.saveAquaStrategy(strategy);
      _upsertAquaStrategy(strategy);
      _aquaTransactionStatus = AquaTransactionStatus.confirmingShip;
      notifyListeners();
      await WalletService.waitForReceipt(shipHash);
      final verification = await _api.verifyAquaTransaction(txHash: shipHash);
      if (verification['shipped'] != true) {
        throw StateError(
          'The ship transaction was confirmed, but Aqua did not emit Shipped.',
        );
      }
      _aquaVerificationStatus = 'Aqua Shipped event verified on-chain';
      strategy['status'] = 'active';
      strategy['proofEvents'] = verification['events'];
      strategy['verifiedAt'] = DateTime.now().toIso8601String();
      _aquaTransactionStatus = AquaTransactionStatus.complete;
      await WalletService.saveAquaStrategy(strategy);
      _upsertAquaStrategy(strategy);
      _refreshAquaSummary();

      _activities.insert(
        0,
        ActivityItem(
          title: '1inch Aqua Strategy Shipped',
          amount: '\$${aquaStrategyUsd.toStringAsFixed(2)}',
          time: 'Just now',
          type: 'execution',
          isPositive: true,
          source: 'Verified Aqua Shipped event',
        ),
      );
      notifyListeners();
    } catch (error) {
      _aquaTransactionStatus = AquaTransactionStatus.failed;
      _aquaTransactionError = WalletService.describeError(error);
      final pending = _aquaStrategies.where((item) =>
          item['status'] == 'preparing' || item['status'] == 'approving');
      for (final strategy in pending) {
        strategy['lastError'] = _aquaTransactionError;
        await WalletService.saveAquaStrategy(strategy);
      }
      _activities.insert(
        0,
        ActivityItem(
          title: 'Aqua transaction failed',
          amount: WalletService.describeError(error),
          time: 'Just now',
          type: 'update',
          isPositive: false,
          source: 'Wallet',
        ),
      );
      notifyListeners();
      rethrow;
    }
  }

  void _upsertAquaStrategy(Map<String, dynamic> strategy) {
    final hash = strategy['strategyHash'];
    _aquaStrategies.removeWhere((item) => item['strategyHash'] == hash);
    _aquaStrategies.add(strategy);
    _refreshAquaSummary();
    notifyListeners();
  }

  Future<Map<String, dynamic>> verifyAquaTransactionHash(String txHash) async {
    final proof = await _api.verifyAquaTransaction(txHash: txHash.trim());
    if (proof['confirmed'] != true) {
      throw StateError(
          'Transaction is not mined on the selected local fork yet.');
    }
    return proof;
  }

  Future<void> verifyAquaStrategy(
    String strategyHash, {
    bool verifyDock = false,
  }) async {
    final strategy = _aquaStrategies.firstWhere(
      (item) => item['strategyHash'] == strategyHash,
    );
    final txHash = verifyDock
        ? strategy['dockTxHash']?.toString()
        : strategy['shipTxHash']?.toString();
    if (txHash == null || txHash.isEmpty) {
      throw StateError('No transaction hash is saved for this strategy.');
    }
    final proof = await verifyAquaTransactionHash(txHash);
    final eventName = verifyDock ? 'Docked' : 'Shipped';
    final verified = (proof['events'] as List<dynamic>? ?? const [])
        .any((event) => (event as Map)['name'] == eventName);
    if (!verified) {
      throw StateError(
          'Receipt is confirmed, but the $eventName event is missing.');
    }
    if (verifyDock) {
      strategy['status'] = 'docked';
      strategy['dockProofEvents'] = proof['events'];
    } else {
      if (strategy['status'] != 'docked') {
        strategy['status'] = 'active';
      }
      strategy['proofEvents'] = proof['events'];
    }
    strategy['verifiedAt'] = DateTime.now().toIso8601String();
    await WalletService.saveAquaStrategy(strategy);
    _upsertAquaStrategy(strategy);
    _aquaVerificationStatus = 'Verified on-chain: $eventName';
  }

  Future<void> dockAquaStrategy(String strategyHash) async {
    final maker = _walletAddress;
    if (maker == null) {
      throw StateError('Connect the strategy owner wallet before docking.');
    }
    final strategy = _aquaStrategies.firstWhere(
      (item) => item['strategyHash'] == strategyHash,
    );
    final tokens = (strategy['tokens'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((token) => token['token'].toString())
        .toList();
    if (tokens.isEmpty) {
      throw StateError('Saved strategy has no token addresses to dock.');
    }

    _aquaTransactionStatus = AquaTransactionStatus.preparing;
    _aquaTransactionError = null;
    notifyListeners();
    try {
      final prepared = await _api.prepareAquaDock(
        makerAddress: maker,
        strategyHash: strategyHash,
        tokens: tokens,
      );
      final transaction =
          Map<String, dynamic>.from(prepared['transaction'] as Map);
      _aquaTransactionStatus = AquaTransactionStatus.signingDock;
      notifyListeners();
      final dockHash = await WalletService.sendTransaction(
        to: transaction['to'] as String,
        data: transaction['data'] as String,
        value: transaction['value'] as String,
      );
      strategy['dockTxHash'] = dockHash;
      strategy['status'] = 'dock_pending';
      await WalletService.saveAquaStrategy(strategy);
      _upsertAquaStrategy(strategy);
      _aquaLastTransactionHash = dockHash;
      _aquaTransactionStatus = AquaTransactionStatus.confirmingDock;
      notifyListeners();
      await WalletService.waitForReceipt(dockHash);
      await verifyAquaStrategy(strategyHash, verifyDock: true);
      _aquaTransactionStatus = AquaTransactionStatus.complete;
      _aquaVerificationStatus = 'Aqua Docked event verified on-chain';
      notifyListeners();
    } catch (error) {
      _aquaTransactionStatus = AquaTransactionStatus.failed;
      _aquaTransactionError = WalletService.describeError(error);
      strategy['lastError'] = _aquaTransactionError;
      await WalletService.saveAquaStrategy(strategy);
      notifyListeners();
      rethrow;
    }
  }

  // Actions
  void setTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners();
  }

  Future<void> connectWallet([
    String address = '0x71C8390b1c0628373b5e43A2338De3c3d5e939Ac',
    String providerName = 'MetaMask',
  ]) async {
    _isConnected = true;
    _walletAddress = address;
    _walletProvider = providerName;
    _sessionExpiresAt = DateTime.now().add(const Duration(days: 30));

    // Save session to SharedPreferences for 30 days
    await WalletService.saveSession(
      address: address,
      providerName: providerName,
    );
    _portfolioSnapshots = (await WalletService.loadPortfolioSnapshots(address))
        .map(_portfolioSnapshotFromJson)
        .toList();
    _aquaStrategies = _strategiesForCurrentWallet(
      await WalletService.loadAquaStrategies(),
    );
    _refreshAquaSummary();

    // Refresh live Base Sepolia tokens (ETH, USDC, WETH)
    await refreshWalletAssets();

    notifyListeners();
  }

  /// Query live on-chain assets on Base Sepolia
  Future<void> refreshWalletAssets() async {
    final addr = _walletAddress;
    if (addr == null || addr.isEmpty) return;

    _isLoadingAssets = true;
    _walletAssetsError = null;
    notifyListeners();

    try {
      final assets = await WalletService.fetchBaseSepoliaAssets(
        address: addr,
        ethPrice: _ethSpotPrice,
      );
      _walletAssets = assets;
      _totalPortfolioUsd = walletAssetsTotalUsd;
      _refreshAquaSummary();
      await WalletService.savePortfolioSnapshot(
        address: addr,
        totalUsd: _totalPortfolioUsd,
      );
      _portfolioSnapshots = (await WalletService.loadPortfolioSnapshots(addr))
          .map(_portfolioSnapshotFromJson)
          .toList();
    } catch (error) {
      _walletAssetsError = WalletService.describeError(error);
    }

    _isLoadingAssets = false;
    notifyListeners();
  }

  PortfolioSnapshot _portfolioSnapshotFromJson(Map<String, dynamic> json) {
    final capturedAt = DateTime.tryParse(json['capturedAt']?.toString() ?? '');
    final totalUsd = double.tryParse(json['totalUsd']?.toString() ?? '');
    if (capturedAt == null || totalUsd == null || !totalUsd.isFinite) {
      throw const FormatException('Invalid saved portfolio snapshot.');
    }
    return PortfolioSnapshot(capturedAt: capturedAt, totalUsd: totalUsd);
  }

  /// Record a completed or submitted wrap transaction (ETH -> WETH)
  Future<void> recordWrapTransaction(double ethAmount) async {
    _activities.insert(
      0,
      ActivityItem(
        title: 'Wrapped ETH → WETH',
        amount: '+${ethAmount.toStringAsFixed(3)} WETH',
        time: 'Just now',
        type: 'execution',
        isPositive: true,
        source: 'Canonical WETH9 (Base Sepolia)',
      ),
    );

    // If simulating or before block confirmation, update local wallet assets
    final ethIndex = _walletAssets.indexWhere((a) => a.symbol == 'ETH');
    final wethIndex = _walletAssets.indexWhere((a) => a.symbol == 'WETH');

    if (ethIndex != -1 && wethIndex != -1) {
      final curEth = _walletAssets[ethIndex];
      final curWeth = _walletAssets[wethIndex];

      final newEthBal = (curEth.balance - ethAmount).clamp(0.0, 1000.0);
      final newWethBal = curWeth.balance + ethAmount;

      _walletAssets[ethIndex] = WalletAsset(
        symbol: curEth.symbol,
        name: curEth.name,
        contractAddress: curEth.contractAddress,
        decimals: curEth.decimals,
        balance: newEthBal,
        usdPrice: curEth.usdPrice,
        network: curEth.network,
      );

      _walletAssets[wethIndex] = WalletAsset(
        symbol: curWeth.symbol,
        name: curWeth.name,
        contractAddress: curWeth.contractAddress,
        decimals: curWeth.decimals,
        balance: newWethBal,
        usdPrice: curWeth.usdPrice,
        network: curWeth.network,
      );

      _totalPortfolioUsd = walletAssetsTotalUsd;
      _refreshAquaSummary();
    }

    notifyListeners();

    // Query on-chain to sync once block is mined
    await Future.delayed(const Duration(seconds: 4));
    await refreshWalletAssets();
  }

  Future<void> disconnectWallet() async {
    _isConnected = false;
    _walletAddress = null;
    _sessionExpiresAt = null;
    _currentTabIndex = 0;

    await WalletService.clearSession();
    notifyListeners();
  }

  void updateStrategyAmount(double amount) {
    _strategyAmount = amount;
    notifyListeners();
  }

  void updateMaxSpread(double delta) {
    _maxSpread = (_maxSpread + delta).clamp(0.5, 10.0);
    notifyListeners();
  }

  Future<void> activateStrategy() async {
    await depositTo1inchAqua();
    _activities.insert(
      0,
      ActivityItem(
        title: 'Strategy Activated',
        amount: '\$${_strategyAmount.toStringAsFixed(2)}',
        time: 'Just now',
        type: 'execution',
        isPositive: true,
        source: '1inch Aqua / Base',
      ),
    );
    notifyListeners();
  }

  Future<void> activateStrategyWithWallet(BuildContext context) async {
    _aquaTransactionStatus = AquaTransactionStatus.preparing;
    _aquaTransactionError = null;
    notifyListeners();
    try {
      await WalletService.ensureAppKitSession(context);
      await activateStrategy();
    } catch (error) {
      _aquaTransactionStatus = AquaTransactionStatus.failed;
      _aquaTransactionError = WalletService.describeError(error);
      notifyListeners();
      rethrow;
    }
  }
}

import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:http/http.dart' as http;

class ApiService {
  // Configurable backend URL: on Android emulator 10.0.2.2 points to host PC port 3001
  final String baseUrl;

  static const String _configuredBaseUrl =
      String.fromEnvironment('BACKEND_URL');

  static String get defaultBaseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    if (kIsWeb) return 'http://localhost:3001';
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3001';
    } catch (_) {}
    return 'http://localhost:3001';
  }

  ApiService({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  static const bool localBaseFork = bool.fromEnvironment(
    'LOCAL_BASE_FORK',
    defaultValue: !kReleaseMode,
  );
  static const String activeAquaChain = 'base_sepolia';

  Future<Map<String, dynamic>> getAquaDeploymentStatus() async {
    final response = await http
        .get(Uri.parse('$baseUrl/api/aqua/status'))
        .timeout(const Duration(seconds: 15));
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError(
        'Aqua backend returned an invalid status response. Restart it in local-fork mode.',
      );
    }
    final body = decoded;
    if (response.statusCode != 200 || body['ready'] != true) {
      final errors = (body['errors'] as List<dynamic>? ?? const [])
          .map((error) => error.toString())
          .join(' ');
      throw StateError(
        errors.isEmpty
            ? 'Aqua RPC is not ready. Restart the backend in local-fork mode.'
            : errors,
      );
    }
    return body;
  }

  // ─── 1inch Aqua Protocol Integration ───────────────────────────────────────

  Future<Map<String, dynamic>> getAquaPosition({String? makerAddress}) async {
    final query = makerAddress != null ? '?maker=$makerAddress' : '';
    final uri = Uri.parse('$baseUrl/api/aqua/position$query');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to fetch 1inch Aqua position');
    }
  }

  Future<Map<String, dynamic>> prepareAquaDeposit({
    required String makerAddress,
    required double totalDepositUsd,
    double? wethAmount,
    double? usdcAmount,
    String? chain,
  }) async {
    final uri = Uri.parse('$baseUrl/api/aqua/deposit');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'makerAddress': makerAddress,
        'totalDepositUsd': totalDepositUsd,
        if (wethAmount != null) 'wethAmount': wethAmount,
        if (usdcAmount != null) 'usdcAmount': usdcAmount,
        'chain': chain ?? activeAquaChain,
      }),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) return body;
    throw StateError(
      body['error']?.toString() ?? 'Failed to prepare Aqua deposit',
    );
  }

  Future<List<Map<String, dynamic>>> getAquaStrategies(
      {String? makerAddress}) async {
    final query = makerAddress != null ? '?maker=$makerAddress' : '';
    final uri = Uri.parse('$baseUrl/api/aqua/strategies$query');
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch Aqua strategies');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['strategies'] as List<dynamic>)
        .map((item) => item as Map<String, dynamic>)
        .toList();
  }

  Future<Map<String, dynamic>> prepareAquaDock({
    required String makerAddress,
    required String strategyHash,
    required List<String> tokens,
    String? chain,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/aqua/dock'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'makerAddress': makerAddress,
        'strategyHash': strategyHash,
        'tokens': tokens,
        'chain': chain ?? activeAquaChain,
      }),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw StateError(
        body['error']?.toString() ?? 'Failed to prepare Aqua dock transaction',
      );
    }
    return body;
  }

  Future<Map<String, dynamic>> verifyAquaTransaction({
    required String txHash,
    String? chain,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/api/aqua/verify?txHash=$txHash&chain=${chain ?? activeAquaChain}',
    );
    final response = await http.get(uri);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw Exception(
          body['error']?.toString() ?? 'Failed to verify Aqua transaction');
    }
    return body;
  }

  Future<Map<String, dynamic>> executeAquaSwap({
    required String makerAddress,
    double amountIn = 10.0,
    int minSpreadBps = 10,
    int maxSpreadBps = 300,
    double spotEthPrice = 2600.0,
  }) async {
    final uri = Uri.parse('$baseUrl/api/aqua/swap');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'makerAddress': makerAddress,
        'amountIn': amountIn,
        'minSpreadBps': minSpreadBps,
        'maxSpreadBps': maxSpreadBps,
        'spotEthPrice': spotEthPrice,
      }),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> prepareAquaSwap({
    required String strategyHash,
    required String strategy,
    required String tokenIn,
    required String tokenOut,
    required String amountIn,
    String? chain,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/aqua/swap/prepare'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'strategyHash': strategyHash,
        'strategy': strategy,
        'tokenIn': tokenIn,
        'tokenOut': tokenOut,
        'amountIn': amountIn,
        'chain': chain ?? activeAquaChain,
      }),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode != 200) {
      throw StateError(
          body['error']?.toString() ?? 'Unable to prepare Aqua swap');
    }
    return body;
  }
}

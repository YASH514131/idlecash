import 'package:flutter/material.dart';

class TokenIcon extends StatelessWidget {
  final String symbol;
  final double size;

  const TokenIcon({
    super.key,
    required this.symbol,
    this.size = 32,
  });

  String? get _assetPath => switch (symbol.toUpperCase()) {
        'ETH' => 'lib/assets/images/eth.jpg',
        'WETH' => 'lib/assets/images/weth.png',
        'USDC' => 'lib/assets/images/usdc.png',
        _ => null,
      };

  IconData get _fallbackIcon => switch (symbol.toUpperCase()) {
        'USDC' => Icons.attach_money,
        _ => Icons.diamond_outlined,
      };

  Color get _fallbackColor => switch (symbol.toUpperCase()) {
        'USDC' => const Color(0xFF2775CA),
        _ => const Color(0xFF627EEA),
      };

  @override
  Widget build(BuildContext context) {
    final assetPath = _assetPath;
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: assetPath == null
            ? _buildFallback()
            : Image.asset(
                assetPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildFallback(),
              ),
      ),
    );
  }

  Widget _buildFallback() {
    return ColoredBox(
      color: _fallbackColor,
      child: Icon(
        _fallbackIcon,
        size: size * 0.55,
        color: Colors.white,
      ),
    );
  }
}

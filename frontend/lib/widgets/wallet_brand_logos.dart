import 'package:flutter/material.dart';

/// Real High-Resolution MetaMask Fox Logo from assets with vector fallback
class MetaMaskLogo extends StatelessWidget {
  final double size;

  const MetaMaskLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/metamask.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Image.asset(
          'lib/assets/images/metamask.png',
          width: size,
          height: size,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Image.asset(
            'assets/images/metmask.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => CustomPaint(
              size: Size(size, size),
              painter: _MetaMaskFoxPainter(),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaMaskFoxPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final paintMain = Paint()..color = const Color(0xFFF6851B)..style = PaintingStyle.fill;
    final paintDark = Paint()..color = const Color(0xFFE2761B)..style = PaintingStyle.fill;
    final paintFace = Paint()..color = const Color(0xFFCD6116)..style = PaintingStyle.fill;
    final paintEye = Paint()..color = const Color(0xFF161616)..style = PaintingStyle.fill;
    final paintSnout = Paint()..color = const Color(0xFFD7C1B3)..style = PaintingStyle.fill;

    // Outer ears / head silhouette
    final head = Path()
      ..moveTo(w * 0.12, h * 0.15)
      ..lineTo(w * 0.38, h * 0.36)
      ..lineTo(w * 0.62, h * 0.36)
      ..lineTo(w * 0.88, h * 0.15)
      ..lineTo(w * 0.82, h * 0.60)
      ..lineTo(w * 0.50, h * 0.90)
      ..lineTo(w * 0.18, h * 0.60)
      ..close();
    canvas.drawPath(head, paintMain);

    // Darker cheek polygons
    final leftCheek = Path()
      ..moveTo(w * 0.18, h * 0.60)
      ..lineTo(w * 0.38, h * 0.36)
      ..lineTo(w * 0.50, h * 0.65)
      ..close();
    canvas.drawPath(leftCheek, paintDark);

    final rightCheek = Path()
      ..moveTo(w * 0.82, h * 0.60)
      ..lineTo(w * 0.62, h * 0.36)
      ..lineTo(w * 0.50, h * 0.65)
      ..close();
    canvas.drawPath(rightCheek, paintFace);

    // Snout
    final snout = Path()
      ..moveTo(w * 0.36, h * 0.65)
      ..lineTo(w * 0.64, h * 0.65)
      ..lineTo(w * 0.50, h * 0.88)
      ..close();
    canvas.drawPath(snout, paintSnout);

    // Eyes
    canvas.drawCircle(Offset(w * 0.36, h * 0.52), w * 0.055, paintEye);
    canvas.drawCircle(Offset(w * 0.64, h * 0.52), w * 0.055, paintEye);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Real Official Coinbase Wallet Logo
class CoinbaseWalletLogo extends StatelessWidget {
  final double size;

  const CoinbaseWalletLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF0052FF), // Official Coinbase Blue
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: size * 0.54,
          height: size * 0.54,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size * 0.15),
          ),
          child: Center(
            child: Container(
              width: size * 0.22,
              height: size * 0.22,
              decoration: BoxDecoration(
                color: const Color(0xFF0052FF),
                borderRadius: BorderRadius.circular(size * 0.05),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Real Official WalletConnect Logo
class WalletConnectLogo extends StatelessWidget {
  final double size;

  const WalletConnectLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF3B99FC), // Official WalletConnect Blue
        shape: BoxShape.circle,
      ),
      child: Center(
        child: CustomPaint(
          size: Size(size * 0.62, size * 0.38),
          painter: _WalletConnectPainter(),
        ),
      ),
    );
  }
}

class _WalletConnectPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(0, h * 0.4)
      ..quadraticBezierTo(w * 0.15, 0, w * 0.32, h * 0.4)
      ..lineTo(w * 0.5, h * 0.95)
      ..lineTo(w * 0.68, h * 0.4)
      ..quadraticBezierTo(w * 0.85, 0, w, h * 0.4);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Real Official Rainbow Wallet Logo
class RainbowWalletLogo extends StatelessWidget {
  final double size;

  const RainbowWalletLogo({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF4081),
            Color(0xFFFFAB00),
            Color(0xFF00E676),
            Color(0xFF00B0FF),
          ],
        ),
      ),
    );
  }
}

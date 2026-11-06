import 'dart:math' as math;
import 'package:flutter/material.dart';

class SleekBackground extends StatelessWidget {
  final Widget child;
  final String? backgroundImage;
  final double overlayOpacity;
  final bool showWaves;

  const SleekBackground({
    super.key,
    required this.child,
    this.backgroundImage = 'assets/images/idlecash.jpg',
    this.overlayOpacity = 0.35,
    this.showWaves = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Pure black base
        Container(color: const Color(0xFF000000)),

        // 1. Asset Background Image (e.g. idlecash.jpg or landpapge_1.jpg)
        if (backgroundImage != null)
          Positioned.fill(
            child: Image.asset(
              backgroundImage!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),

        // 2. Subtle Dark Scrim / Vignette to ensure pristine text contrast
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: overlayOpacity * 0.7),
                  Colors.black.withValues(alpha: overlayOpacity),
                  Colors.black.withValues(alpha: overlayOpacity * 1.2),
                ],
              ),
            ),
          ),
        ),

        // 3. Fallback / Enhancement Wave Painter
        if (showWaves && backgroundImage == null)
          Positioned.fill(
            child: CustomPaint(
              painter: _MetallicWavePainter(),
            ),
          ),

        // 4. Foreground Content
        SafeArea(child: child),
      ],
    );
  }
}

class _MetallicWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.6, 0.4),
        radius: 0.8,
        colors: [
          const Color(0xFF202636).withValues(alpha: 0.25),
          const Color(0xFF0F1219).withValues(alpha: 0.08),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, glowPaint);

    final path1 = Path();
    path1.moveTo(0, size.height * 0.15);
    path1.cubicTo(
      size.width * 0.4,
      size.height * 0.05,
      size.width * 0.6,
      size.height * 0.35,
      size.width,
      size.height * 0.25,
    );
    path1.lineTo(size.width, size.height * 0.35);
    path1.cubicTo(
      size.width * 0.6,
      size.height * 0.45,
      size.width * 0.3,
      size.height * 0.2,
      0,
      size.height * 0.25,
    );
    path1.close();

    final wavePaint1 = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.07),
          const Color(0xFF4B5568).withValues(alpha: 0.04),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawPath(path1, wavePaint1);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class IdleCashBrandLogo extends StatelessWidget {
  final double size;

  const IdleCashBrandLogo({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFE2E8F0),
          Color(0xFF94A3B8),
        ],
      ).createShader(Offset.zero & size);

    final barWidth = size.width * 0.18;
    final r = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx - size.width * 0.22, center.dy + size.height * 0.12),
        width: barWidth,
        height: size.height * 0.55,
      ),
      Radius.circular(barWidth / 2),
    );

    final r2 = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: barWidth,
        height: size.height * 0.75,
      ),
      Radius.circular(barWidth / 2),
    );

    final r3 = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(center.dx + size.width * 0.22, center.dy - size.height * 0.12),
        width: barWidth,
        height: size.height * 0.55,
      ),
      Radius.circular(barWidth / 2),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 4);
    canvas.translate(-center.dx, -center.dy);

    canvas.drawRRect(r, paint);
    canvas.drawRRect(r2, paint);
    canvas.drawRRect(r3, paint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

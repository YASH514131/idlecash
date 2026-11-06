import 'package:flutter/material.dart';

class GlassCubesGraphic extends StatelessWidget {
  final double size;

  const GlassCubesGraphic({super.key, this.size = 200});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _IsometricGlassCubesPainter(),
      ),
    );
  }
}

class _IsometricGlassCubesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.45, size.height * 0.45);

    // Cube 1 (Large Main Glass Cube)
    _drawIsometricCube(
      canvas,
      center: center,
      size: size.width * 0.32,
      opacity: 0.9,
    );

    // Cube 2 (Small Glass Cube floating below to the right)
    _drawIsometricCube(
      canvas,
      center: Offset(size.width * 0.72, size.height * 0.68),
      size: size.width * 0.16,
      opacity: 0.75,
    );
  }

  void _drawIsometricCube(
    Canvas canvas, {
    required Offset center,
    required double size,
    required double opacity,
  }) {
    final dx = size * 0.866; // cos(30 deg)
    final dy = size * 0.5; // sin(30 deg)

    // Top face
    final topPath = Path();
    topPath.moveTo(center.dx, center.dy - size);
    topPath.lineTo(center.dx + dx, center.dy - size + dy);
    topPath.lineTo(center.dx, center.dy - size + 2 * dy);
    topPath.lineTo(center.dx - dx, center.dy - size + dy);
    topPath.close();

    final topPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.25 * opacity),
          Colors.white.withValues(alpha: 0.08 * opacity),
        ],
      ).createShader(topPath.getBounds())
      ..style = PaintingStyle.fill;

    // Left face
    final leftPath = Path();
    leftPath.moveTo(center.dx - dx, center.dy - size + dy);
    leftPath.lineTo(center.dx, center.dy - size + 2 * dy);
    leftPath.lineTo(center.dx, center.dy + dy);
    leftPath.lineTo(center.dx - dx, center.dy);
    leftPath.close();

    final leftPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF4A5568).withValues(alpha: 0.35 * opacity),
          const Color(0xFF1A202C).withValues(alpha: 0.15 * opacity),
        ],
      ).createShader(leftPath.getBounds())
      ..style = PaintingStyle.fill;

    // Right face
    final rightPath = Path();
    rightPath.moveTo(center.dx, center.dy - size + 2 * dy);
    rightPath.lineTo(center.dx + dx, center.dy - size + dy);
    rightPath.lineTo(center.dx + dx, center.dy);
    rightPath.lineTo(center.dx, center.dy + dy);
    rightPath.close();

    final rightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF718096).withValues(alpha: 0.25 * opacity),
          const Color(0xFF2D3748).withValues(alpha: 0.10 * opacity),
        ],
      ).createShader(rightPath.getBounds())
      ..style = PaintingStyle.fill;

    // Glass edge highlights
    final edgePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45 * opacity)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Draw faces
    canvas.drawPath(leftPath, leftPaint);
    canvas.drawPath(rightPath, rightPaint);
    canvas.drawPath(topPath, topPaint);

    // Draw borders
    canvas.drawPath(leftPath, edgePaint);
    canvas.drawPath(rightPath, edgePaint);
    canvas.drawPath(topPath, edgePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

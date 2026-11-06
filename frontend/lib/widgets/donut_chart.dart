import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DonutChart extends StatelessWidget {
  final double percentage; // e.g. 67 for 67%
  final double size;

  const DonutChart({
    super.key,
    required this.percentage,
    this.size = 180,
  });

  @override
  Widget build(BuildContext context) {
    final safePercentage =
        percentage.isFinite ? percentage.clamp(0.0, 100.0).toDouble() : 0.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DonutChartPainter(percentage: safePercentage),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${safePercentage.toInt()}%',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final double percentage;

  _DonutChartPainter({required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    final safePercentage =
        percentage.isFinite ? percentage.clamp(0.0, 100.0).toDouble() : 0.0;
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.12;
    final radius = (size.width - strokeWidth) / 2;

    // Background track (dark slate)
    final trackPaint = Paint()
      ..color = const Color(0xFF1E2433)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Active progress arc (gradient from cyan to blue/white)
    final sweepAngle = (safePercentage / 100) * 2 * math.pi;
    if (sweepAngle <= 0) {
      return;
    }

    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + sweepAngle,
        colors: const [
          Color(0xFF00E599),
          Color(0xFF00D2FF),
          Color(0xFF0052FF),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) =>
      oldDelegate.percentage != percentage;
}

import 'package:flutter/material.dart';

class SparklineChart extends StatelessWidget {
  final List<double> data;
  final double height;
  final double width;
  final Color lineColor;
  final bool showFill;

  const SparklineChart({
    super.key,
    required this.data,
    this.height = 54,
    this.width = 110,
    this.lineColor = Colors.white,
    this.showFill = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: CustomPaint(
        painter: _SparklinePainter(
          data: data,
          lineColor: lineColor,
          showFill: showFill,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final bool showFill;

  _SparklinePainter({
    required this.data,
    required this.lineColor,
    required this.showFill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    if (data.length < 2) {
      final placeholderPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.2)
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round;
      const dashWidth = 3.0;
      const dashGap = 5.0;
      final baselineY = size.height / 2;
      for (var x = 0.0; x < size.width; x += dashWidth + dashGap) {
        canvas.drawLine(
          Offset(x, baselineY),
          Offset((x + dashWidth).clamp(0, size.width), baselineY),
          placeholderPaint,
        );
      }

      if (data.length == 1) {
        final markerPaint = Paint()..color = lineColor.withValues(alpha: 0.75);
        canvas.drawCircle(Offset(size.width, baselineY), 3, markerPaint);
      }
      return;
    }

    final min = data.reduce((a, b) => a < b ? a : b);
    final max = data.reduce((a, b) => a > b ? a : b);
    final range = max - min == 0 ? 1.0 : max - min;

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final y = size.height - ((data[i] - min) / range) * (size.height - 8) - 4;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final prevX = (i - 1) * stepX;
        final prevY =
            size.height - ((data[i - 1] - min) / range) * (size.height - 8) - 4;
        final cx = (prevX + x) / 2;
        path.cubicTo(cx, prevY, cx, y, x, y);
        fillPath.cubicTo(cx, prevY, cx, y, x, y);
      }
    }

    if (showFill) {
      fillPath.lineTo(size.width, size.height);
      fillPath.close();

      final fillPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.18),
            lineColor.withValues(alpha: 0.0),
          ],
        ).createShader(Offset.zero & size);

      canvas.drawPath(fillPath, fillPaint);
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) => true;
}

class MiniBarChart extends StatelessWidget {
  final List<double> values;
  final double height;
  final double width;

  const MiniBarChart({
    super.key,
    this.values = const [6, 9, 13, 17, 22, 28, 33, 42],
    this.height = 42,
    this.width = 82,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = values.reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: height,
      width: width,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(values.length, (i) {
          final val = values[i];
          final barHeight = (val / maxVal) * height;

          // Progressive white-silver gradient as seen in screenshot
          final opacity = 0.25 + (i / (values.length - 1)) * 0.75;

          return Container(
            width: 5,
            height: barHeight < 5 ? 5 : barHeight,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(2.5),
            ),
          );
        }),
      ),
    );
  }
}

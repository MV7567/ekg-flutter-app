import 'dart:math';   // min, max
import 'package:flutter/material.dart';
import '../rr_stats.dart';

// the tachogram: every RR interval (vertical, ms) over the time of the recording (horizontal)
// a calm heart makes a slow wave going up and down with the breathing,
// a single point far away is an artifact that got through, a step is a change of the heart rate
class RrTachogram extends StatelessWidget {
  const RrTachogram({super.key, required this.points, required this.durationSeconds});

  final List<RrPoint> points;
  final double durationSeconds;   // the whole recording, the right edge of the chart

  @override
  Widget build(BuildContext context) {
    ColorScheme colors = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _TachogramPainter(points, durationSeconds, colors.primary, colors.outlineVariant,
          Theme.of(context).textTheme.bodySmall!.copyWith(color: colors.onSurfaceVariant)),
      size: Size.infinite,
    );
  }

  // the vertical range in ms: the lowest and highest interval, rounded out to 50 ms,
  // at least 200 ms high, so a very steady rhythm doesn't look like big jumps
  static (double, double) range(List<RrPoint> points) {
    double low = points.map((p) => p.rrMs).reduce(min);
    double high = points.map((p) => p.rrMs).reduce(max);
    low = (low / 50).floor() * 50;
    high = (high / 50).ceil() * 50;
    if (high - low < 200) {
      double middle = (low + high) / 2;
      low = ((middle - 100) / 50).floor() * 50;
      high = low + 200;
    }
    return (low, high);
  }
}

class _TachogramPainter extends CustomPainter {
  _TachogramPainter(this.points, this.durationSeconds, this.lineColor, this.gridColor, this.textStyle);

  final List<RrPoint> points;
  final double durationSeconds;
  final Color lineColor, gridColor;
  final TextStyle textStyle;

  static const double _labelWidth = 44;   // room on the left for "1000 ms"

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || durationSeconds <= 0) return;
    var (low, high) = RrTachogram.range(points);
    double left = _labelWidth;
    double width = size.width - left;
    double x(double seconds) => left + seconds / durationSeconds * width;
    double y(double ms) => size.height - (ms - low) / (high - low) * size.height;

    // 3 horizontal grid lines with their values: bottom, middle, top
    Paint grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (double ms in [low, (low + high) / 2, high]) {
      double lineY = y(ms).clamp(0.5, size.height - 0.5);
      canvas.drawLine(Offset(left, lineY), Offset(size.width, lineY), grid);
      TextPainter label = TextPainter(
        text: TextSpan(text: '${ms.round()} ms', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      double labelY = (lineY - label.height / 2).clamp(0, size.height - label.height);
      label.paint(canvas, Offset(0, labelY));
    }

    // the intervals as a line with a dot on every one
    Paint line = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    Path path = Path()..moveTo(x(points.first.seconds), y(points.first.rrMs));
    for (RrPoint p in points.skip(1)) {
      path.lineTo(x(p.seconds), y(p.rrMs));
    }
    canvas.drawPath(path, line);
    Paint dot = Paint()..color = lineColor;
    for (RrPoint p in points) {
      canvas.drawCircle(Offset(x(p.seconds), y(p.rrMs)), 2, dot);
    }
  }

  @override
  bool shouldRepaint(_TachogramPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.durationSeconds != durationSeconds ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.textStyle != textStyle;
}

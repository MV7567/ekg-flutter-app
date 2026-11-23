import 'dart:math';   // min, max
import 'package:flutter/material.dart';
import 'ekg_chart.dart';   // EkgChartColors, the same paper / monitor colors

// the median beat of a recording (see QrsWidth.medianBeat) on EKG paper,
// the measured QRS as a shaded band between two lines, its width written above it
// the paper has square boxes like the real one: 1 small box = 40 ms in time,
// the amplitude is fitted to the height (one beat must fit whatever its size)
class MedianBeatChart extends StatelessWidget {
  const MedianBeatChart({super.key, required this.beat, required this.qrs, required this.sampleRateHz, this.tEnd});

  final List<double> beat;   // mV
  final (int, int)? qrs;     // start and end of the QRS in beat, null = not measured
  final int sampleRateHz;
  final int? tEnd;           // the end of the T wave in beat, null = no QT measured

  // the band and the lines of the QRS, teal: different from all the markers of the EKG chart
  static const Color qrsColor = Color(0xFF00897B);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MedianBeatPainter(beat, qrs, sampleRateHz, EkgChartColors.of(context), tEnd),
      size: Size.infinite,
    );
  }
}

class _MedianBeatPainter extends CustomPainter {
  _MedianBeatPainter(this.beat, this.qrs, this.sampleRateHz, this.colors, this.tEnd);

  final List<double> beat;
  final (int, int)? qrs;
  final int sampleRateHz;
  final EkgChartColors colors;
  final int? tEnd;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.background);
    if (beat.length < 2) return;

    // time: the whole beat = the whole width, the grid boxes are squares of 40 ms
    double xStep = size.width / (beat.length - 1);
    double box = 0.040 * sampleRateHz * xStep;
    Paint small = Paint()
      ..color = colors.smallGrid
      ..strokeWidth = 0.5;
    Paint big = Paint()
      ..color = colors.bigGrid
      ..strokeWidth = 1;
    for (int i = 0; i * box <= size.width; i++) {
      canvas.drawLine(Offset(i * box, 0), Offset(i * box, size.height), i % 5 == 0 ? big : small);
    }
    for (int i = 0; i * box <= size.height; i++) {
      canvas.drawLine(Offset(0, i * box), Offset(size.width, i * box), i % 5 == 0 ? big : small);
    }

    // amplitude: the beat from its lowest to its highest point fills 80 % of the height
    double low = beat.reduce(min), high = beat.reduce(max);
    double pxPerMv = 0.8 * size.height / max(high - low, 0.05);
    double middle = (low + high) / 2;
    double y(double mv) => size.height / 2 - (mv - middle) * pxPerMv;

    // the QRS band under the line
    (int, int)? q = qrs;
    if (q != null) {
      double x0 = q.$1 * xStep, x1 = q.$2 * xStep;
      canvas.drawRect(Rect.fromLTRB(x0, 0, x1, size.height),
          Paint()..color = MedianBeatChart.qrsColor.withValues(alpha: 0.15));
      Paint edge = Paint()
        ..color = MedianBeatChart.qrsColor
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(x0, 0), Offset(x0, size.height), edge);
      canvas.drawLine(Offset(x1, 0), Offset(x1, size.height), edge);
    }

    Path line = Path()..moveTo(0, y(beat[0]));
    for (int i = 1; i < beat.length; i++) {
      line.lineTo(i * xStep, y(beat[i]));
    }
    canvas.drawPath(
        line,
        Paint()
          ..color = colors.line
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);

    _drawQt(canvas, size, xStep);

    // a frame around the paper: the grid starts at the top left, so without it the bottom and
    // the right edge end in the middle of a box and the chart looks cut off
    canvas.drawRect(
        (Offset.zero & size).deflate(0.5),
        Paint()
          ..color = colors.bigGrid
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);

    // "88 ms" at the top, next to the band
    if (q != null) {
      int ms = ((q.$2 - q.$1) * 1000 / sampleRateHz).round();
      TextPainter label = TextPainter(
        text: TextSpan(text: '$ms ms', style: TextStyle(color: MedianBeatChart.qrsColor, fontSize: 12,
            fontWeight: FontWeight.bold, backgroundColor: colors.background.withValues(alpha: 0.85))),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(q.$2 * xStep + 4, 2));
    }
  }

  // the T end: a dashed line, and "QT 380 ms" next to it (from the QRS start)
  void _drawQt(Canvas canvas, Size size, double xStep) {
    (int, int)? q = qrs;
    int? end = tEnd;
    if (q == null || end == null) return;
    double x = end * xStep;
    Paint dash = Paint()
      ..color = MedianBeatChart.qrsColor
      ..strokeWidth = 1.5;
    for (double y = 0; y < size.height; y += 8) {
      canvas.drawLine(Offset(x, y), Offset(x, min(y + 4, size.height)), dash);
    }
    int ms = ((end - q.$1) * 1000 / sampleRateHz).round();
    TextPainter label = TextPainter(
      text: TextSpan(text: 'QT $ms ms', style: TextStyle(color: MedianBeatChart.qrsColor, fontSize: 12,
          fontWeight: FontWeight.bold, backgroundColor: colors.background.withValues(alpha: 0.85))),
      textDirection: TextDirection.ltr,
    )..layout();
    // left of the line if it does not fit on the right
    double left = x + 4 + label.width <= size.width ? x + 4 : x - 4 - label.width;
    label.paint(canvas, Offset(left, size.height - label.height - 2));
  }

  @override
  bool shouldRepaint(covariant _MedianBeatPainter old) =>
      old.beat != beat || old.qrs != qrs || old.sampleRateHz != sampleRateHz || old.colors != colors ||
      old.tEnd != tEnd;
}

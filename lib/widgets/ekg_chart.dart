import 'package:flutter/material.dart';
import '../ekg_buffer.dart';

// widget that shows the samples from an EkgBuffer as a line on EKG paper
// time:      1 big square = 0.2 s, 1 small square = 0.04 s (like paper at 25 mm/s)
// amplitude: 1 big square = mvPerBigSquare (0.5 mV on standard paper at 10 mm/mV)
class EkgChart extends StatelessWidget {
  const EkgChart({
    super.key,
    required this.buffer,
    required this.sampleRateHz,
    this.mvPerBigSquare = 0.5,
  });

  final EkgBuffer buffer;
  final int sampleRateHz;
  final double mvPerBigSquare;

  @override
  Widget build(BuildContext context) {
    // CustomPaint gives us a canvas, the drawing itself is done by _EkgPainter
    return CustomPaint(
      painter: _EkgPainter(buffer, sampleRateHz, mvPerBigSquare),
      size: Size.infinite,   // take all the space the parent gives
    );
  }
}

class _EkgPainter extends CustomPainter {
  // repaint: buffer -> the painter listens to the buffer and repaints by itself
  // every time the buffer calls notifyListeners() (no setState needed)
  _EkgPainter(this.buffer, this.sampleRateHz, this.mvPerBigSquare) : super(repaint: buffer);

  final EkgBuffer buffer;
  final int sampleRateHz;
  final double mvPerBigSquare;

  static const double secondsPerBigSquare = 0.2;

  @override
  void paint(Canvas canvas, Size size) {
    // nothing may be drawn outside the chart (e.g. a big spike over the buttons below)
    canvas.clipRect(Offset.zero & size);

    // background, light pink like EKG paper
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFF5F5));

    // 1. scale: how many pixels is 1 second and 1 mV
    // the whole buffer (5 s) = full width
    double secondsOnScreen = buffer.capacity / sampleRateHz;
    double pxPerSecond = size.width / secondsOnScreen;
    double bigSquarePx = pxPerSecond * secondsPerBigSquare;
    // squares are square: 1 big square is as high as it is wide
    double pxPerMv = bigSquarePx / mvPerBigSquare;
    double zeroY = size.height / 2;   // 0 mV in the middle (the high-pass keeps the line around 0)

    _drawGrid(canvas, size, bigSquarePx, zeroY);

    if (buffer.length >= 2) {
      // 2. build the line: every sample becomes one point (x, y)
      // y: on the screen y grows DOWN, so mV are subtracted
      double xStep = pxPerSecond / sampleRateHz;
      Path path = Path();
      for (int i = 0; i < buffer.length; i++) {
        double x = i * xStep;
        double y = zeroY - buffer[i] * pxPerMv;
        if (i == 0) {
          path.moveTo(x, y);   // start of the line
        } else {
          path.lineTo(x, y);   // line from the previous point to this one
        }
      }

      // 3. draw the line
      Paint linePaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;   // only the line, not a filled shape
      canvas.drawPath(path, linePaint);
    }

    _drawLabel(canvas);
  }

  // grid lines start at the 0 mV line / left edge and go outward every small square,
  // every 5th one is a big square (thicker and darker)
  void _drawGrid(Canvas canvas, Size size, double bigSquarePx, double zeroY) {
    double smallSquarePx = bigSquarePx / 5;
    // on a narrow screen the small squares would be a few pixels -> only big ones then
    bool drawSmall = smallSquarePx >= 4;

    Paint smallPaint = Paint()
      ..color = const Color(0xFFF8C8C8)
      ..strokeWidth = 0.5;
    Paint bigPaint = Paint()
      ..color = const Color(0xFFE88888)
      ..strokeWidth = 1;

    // vertical lines = time
    for (int i = 0; i * smallSquarePx <= size.width; i++) {
      bool big = i % 5 == 0;
      if (!big && !drawSmall) continue;
      double x = i * smallSquarePx;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), big ? bigPaint : smallPaint);
    }

    // horizontal lines = amplitude, symmetric above and below 0 mV
    for (int i = 0; i * smallSquarePx <= size.height / 2; i++) {
      bool big = i % 5 == 0;
      if (!big && !drawSmall) continue;
      Paint paint = big ? bigPaint : smallPaint;
      double dy = i * smallSquarePx;
      canvas.drawLine(Offset(0, zeroY - dy), Offset(size.width, zeroY - dy), paint);
      canvas.drawLine(Offset(0, zeroY + dy), Offset(size.width, zeroY + dy), paint);
    }
  }

  // what one big square means, in the top left corner
  void _drawLabel(Canvas canvas) {
    TextPainter label = TextPainter(
      text: TextSpan(
        text: '1 kratka: ${secondsPerBigSquare.toStringAsFixed(1)} s × '
            '${mvPerBigSquare.toStringAsFixed(mvPerBigSquare < 0.1 ? 3 : 2)} mV',
        style: const TextStyle(color: Colors.black54, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, const Offset(4, 2));
  }

  // called when the widget is rebuilt (e.g. setState on the screen),
  // new data is handled by repaint: buffer, here only a change of settings matters
  @override
  bool shouldRepaint(covariant _EkgPainter oldDelegate) =>
      oldDelegate.buffer != buffer ||
      oldDelegate.sampleRateHz != sampleRateHz ||
      oldDelegate.mvPerBigSquare != mvPerBigSquare;
}

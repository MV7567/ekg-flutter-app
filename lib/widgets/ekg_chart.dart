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
    this.mvPerBigSquare = 0.5,  // not required bc it has a default value
  });

// final: cannot be changed after the constructor, required: must be given when creating the widget
  final EkgBuffer buffer;
  final int sampleRateHz;
  final double mvPerBigSquare;

  // text in the top left corner, e.g. "1 square: 0.2 s × 0.125 mV"
  // static and public, so it can be tested without drawing anything
  static String scaleLabel(double secondsPerSquare, double mvPerSquare) =>
      '1 square: ${_trimmed(secondsPerSquare)} s × ${_trimmed(mvPerSquare)} mV';

  // 3 decimal places without the zeros at the end: 0.500 -> 0.5, 0.250 -> 0.25, 0.125 -> 0.125
  static String _trimmed(double value) {
    String text = value.toStringAsFixed(3);
    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);   // remove the last character
    }
    if (text.endsWith('.')) text = text.substring(0, text.length - 1);   // 1. -> 1
    return text;
  }

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
  // the widget gives the canvas to the painter, the drawing is done by CustomPainter aka _EkgPainter. 
  // we use this because the pre made widget arent enough
  // size.infite means take up all the space from the parent
  _EkgPainter(this.buffer, this.sampleRateHz, this.mvPerBigSquare) : super(repaint: buffer);
  // gives the buffer to the constructor, and the painter listens to it (repaint: buffer), so with every notifyListeners() the painter is called and the chart is redrawn

  // BLE packet -> _processEkgData -> _chartBuffer.addAll -> notifyListeners() -> repaint: buffer -> _EkgPainter.paint
  // setState is not needed, the painter listens to the buffer and repaints by itself
  
  final EkgBuffer buffer;
  final int sampleRateHz;
  final double mvPerBigSquare;

  static const double secondsPerBigSquare = 0.2;  // 1 big square = 0.2 s, 1 small square = 0.04 s (like paper at 25 mm/s)

  @override
  void paint(Canvas canvas, Size size) {
    // nothing may be drawn outside the chart (eg a big spike over the buttons below)
    canvas.clipRect(Offset.zero & size); 
    // offset.zero = top left corner, (0,0), & creates a rectangle from this point to the size 
    // clip react cuts everything besides the created rectangle

    // background, light pink like EKG paper
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFF5F5));
    // the paint brush, .. is a cascade operator, it allows you to call multiple methods on the same object without repeating the object name

    // 1. scale: how many pixels is 1 second and 1 mV
    // the whole buffer (5 s) = full width
    double secondsOnScreen = buffer.capacity / sampleRateHz;    // 1250 / 250 = 5 s
    double pxPerSecond = size.width / secondsOnScreen;          // eg 328 / 5 = 65.6 px/s
    double bigSquarePx = pxPerSecond * secondsPerBigSquare;     // 65.6 * 0.2 = 13.12 px per big square
    double pxPerMv = bigSquarePx / mvPerBigSquare;              // with x2: 13,1 / 0,25 = 52,5 px/mV
    double zeroY = size.height / 2;                             // 100 px = middle
    // 0 mV in the middle (the high-pass keeps the line around 0)

    // the scale depends on the screen width

    _drawGrid(canvas, size, bigSquarePx, zeroY);

    if (buffer.length >= 2) { // because a line needs at least 2 points
      // 2. build the line: every sample becomes one point (x, y)
      // y: on the screen y grows DOWN, so mV are subtracted
      double xStep = pxPerSecond / sampleRateHz;    // 65,6 / 250 = 0,26px per sample
      Path path = Path();
      for (int i = 0; i < buffer.length; i++) {
        double x = i * xStep;
        double y = zeroY - buffer[i] * pxPerMv;
        // converting the sample to a point on the screen, 
        // x - sample number x step, 1 pixels is around 4 samples, its ok it just makes a dense line
        // y - it grows down (0 is the top) 
        if (i == 0) {
          path.moveTo(x, y);   // start of the line
        } else {
          path.lineTo(x, y);   // line from the previous point to this one
        }
        // path is "the guide for the line", moveTo moves the pen without drawing, lineTo draws the line to the previous point
        // first build the path (1250 points) the draw it, much faster than calling drawLine 1250 times
      }

      // 3. draw the line
      Paint linePaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;   // only the line, not a filled shape
      canvas.drawPath(path, linePaint);
    }
    // cascade with 3 setters, the line is black, 1.5 px wide, and only the line is drawn, not a filled shape

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
        text: EkgChart.scaleLabel(secondsPerBigSquare, mvPerBigSquare),
        style: const TextStyle(color: Colors.black54, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, const Offset(4, 2));
  }
  // in Canvas you cant just write text, TextPainter has to place it first (layout() calc the width of the letters and line breaks) and then draw it at point (4,2)
  // textDirection: ltr (left-to-right)
  // cascade again, TextPainter(...)..layout(), creates object, places the text and returns object

  // called when the widget is rebuilt (e.g. setState on the screen),
  // new data is handled by repaint: buffer, here only a change of settings matters
  @override
  bool shouldRepaint(covariant _EkgPainter oldDelegate) =>
      oldDelegate.buffer != buffer ||
      oldDelegate.sampleRateHz != sampleRateHz ||
      oldDelegate.mvPerBigSquare != mvPerBigSquare;
} // with every build() a new _EkgPainter is created, flutter asks if the new painter is goin gtoi draw something different than the previous one, if not then its skispped
// new data is taken care of by repaint: buffer, so here e compare only settings, with changing x1/x2/x4 the result is true
// covariant narrows the type of the parameter; the base class calls it a CustomPainter, covariant says its always gonna be _EkgPainter

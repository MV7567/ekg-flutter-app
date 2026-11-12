import 'package:flutter/foundation.dart';   // ValueListenable
import 'package:flutter/material.dart';
import '../ekg_auto_scale.dart';
import '../ekg_buffer.dart';
import '../l10n/app_localizations.dart';

// widget that shows the samples from an EkgBuffer as a line on EKG paper
// time:      1 big square = 0.2 s, 1 small square = 0.04 s (like paper at 25 mm/s)
// amplitude: 1 big square = mvPerBigSquare (0.5 mV on standard paper at 10 mm/mV),
//            or EkgChart.autoZoom: the chart picks the step itself (see EkgAutoScale)
// stateful: Auto has to remember its last step between the repaints, otherwise it would jump
class EkgChart extends StatefulWidget {
  const EkgChart({
    super.key,
    required this.buffer,
    required this.sampleRateHz,
    this.mvPerBigSquare = 0.5,  // not required bc it has a default value
    this.beatMarkers,
  });

// final: cannot be changed after the constructor, required: must be given when creating the widget
  final EkgBuffer buffer;
  final int sampleRateHz;
  final double mvPerBigSquare;
  // optional: where the R waves are, as positions in the buffer (0 = oldest sample),
  // a small red triangle is drawn under each one; null = no markers (live chart)
  final ValueListenable<List<int>>? beatMarkers;

  // the mvPerBigSquare value that means "Auto" (a real scale is never 0)
  static const double autoZoom = 0;

  // text in the top left corner, e.g. "1 square: 0.2 s × 0.125 mV"
  // static and public, so it can be tested without drawing anything
  // t = texts in the chosen language ("1 square" / "1 kratka"), the numbers are formatted here
  static String scaleLabel(AppLocalizations t, double secondsPerSquare, double mvPerSquare) =>
      t.chartScale(_trimmed(secondsPerSquare), _trimmed(mvPerSquare));

  // 4 decimal places without the zeros at the end: 0.5000 -> 0.5, 0.1250 -> 0.125, 0.0625 -> 0.0625 (×8)
  static String _trimmed(double value) {
    String text = value.toStringAsFixed(4);
    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);   // remove the last character
    }
    if (text.endsWith('.')) text = text.substring(0, text.length - 1);   // 1. -> 1
    return text;
  }

  @override
  State<EkgChart> createState() => _EkgChartState();
}

class _EkgChartState extends State<EkgChart> {
  // lives as long as the chart, keeps the last Auto step
  final EkgAutoScale _autoScale = EkgAutoScale();

  @override
  Widget build(BuildContext context) {
    // CustomPaint gives us a canvas, the drawing itself is done by _EkgPainter
    // the painter has no context, so the texts of the chosen language are taken here and passed in
    // (the scale label itself is made in paint: with Auto only the painter knows the step)
    AppLocalizations t = AppLocalizations.of(context);
    // the same for the colors: pink paper in the light theme, a dark monitor in the dark one
    EkgChartColors colors = EkgChartColors.of(context);
    return CustomPaint(
      painter: _EkgPainter(widget.buffer, widget.sampleRateHz, widget.mvPerBigSquare, t, widget.beatMarkers,
          colors, _autoScale),
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
  // Listenable.merge: repaint when the buffer OR the markers change
  _EkgPainter(this.buffer, this.sampleRateHz, this.mvPerBigSquare, this.texts, this.beatMarkers, this.colors,
      this.autoScale)
      : super(repaint: Listenable.merge([buffer, beatMarkers]));
  // gives the buffer to the constructor, and the painter listens to it (repaint: buffer), so with every notifyListeners() the painter is called and the chart is redrawn

  // BLE packet -> _processEkgData -> _chartBuffer.addAll -> notifyListeners() -> repaint: buffer -> _EkgPainter.paint
  // setState is not needed, the painter listens to the buffer and repaints by itself
  
  final EkgBuffer buffer;
  final int sampleRateHz;
  final double mvPerBigSquare;   // EkgChart.autoZoom = Auto
  final AppLocalizations texts;   // for the scale text in the top left corner
  final ValueListenable<List<int>>? beatMarkers;
  final EkgChartColors colors;   // paper or monitor
  final EkgAutoScale autoScale;  // remembers the Auto step, owned by the chart widget

  static const double secondsPerBigSquare = 0.2;  // 1 big square = 0.2 s, 1 small square = 0.04 s (like paper at 25 mm/s)

  @override
  void paint(Canvas canvas, Size size) {
    // nothing may be drawn outside the chart (eg a big spike over the buttons below)
    canvas.clipRect(Offset.zero & size); 
    // offset.zero = top left corner, (0,0), & creates a rectangle from this point to the size 
    // clip react cuts everything besides the created rectangle

    // background, light pink like EKG paper
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.background);
    // the paint brush, .. is a cascade operator, it allows you to call multiple methods on the same object without repeating the object name

    // 1. scale: how many pixels is 1 second and 1 mV
    // the whole buffer (5 s) = full width
    double secondsOnScreen = buffer.capacity / sampleRateHz;    // 1250 / 250 = 5 s
    double pxPerSecond = size.width / secondsOnScreen;          // eg 328 / 5 = 65.6 px/s
    double bigSquarePx = pxPerSecond * secondsPerBigSquare;     // 65.6 * 0.2 = 13.12 px per big square
    // Auto: the step is chosen from the samples and from how many squares fit above the 0 mV line
    bool auto = mvPerBigSquare == EkgChart.autoZoom;
    double scale = auto
        ? autoScale.update(buffer, sampleRateHz, size.height / 2 / bigSquarePx)
        : mvPerBigSquare;
    double pxPerMv = bigSquarePx / scale;              // with x2: 13,1 / 0,25 = 52,5 px/mV
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
        ..color = colors.line
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;   // only the line, not a filled shape
      canvas.drawPath(path, linePaint);
    }
    // cascade with 3 setters, the line is black, 1.5 px wide, and only the line is drawn, not a filled shape

    _drawBeatMarkers(canvas, size, pxPerSecond / sampleRateHz);
    String label = EkgChart.scaleLabel(texts, secondsPerBigSquare, scale);
    _drawLabel(canvas, auto ? '$label · ${texts.chartZoomAuto}' : label);
  }

  // a small red triangle at the bottom edge under every R wave, pointing up at it
  void _drawBeatMarkers(Canvas canvas, Size size, double xStep) {
    List<int>? markers = beatMarkers?.value;
    if (markers == null || markers.isEmpty) return;
    Paint red = Paint()..color = colors.marker;
    for (int position in markers) {
      double x = position * xStep;
      Path triangle = Path()
        ..moveTo(x, size.height - 10)       // tip
        ..lineTo(x - 5, size.height)        // bottom left
        ..lineTo(x + 5, size.height)        // bottom right
        ..close();
      canvas.drawPath(triangle, red);
    }
  }

  // grid lines start at the 0 mV line / left edge and go outward every small square,
  // every 5th one is a big square (thicker and darker)
  void _drawGrid(Canvas canvas, Size size, double bigSquarePx, double zeroY) {
    double smallSquarePx = bigSquarePx / 5;
    // on a narrow screen the small squares would be a few pixels -> only big ones then
    bool drawSmall = smallSquarePx >= 4;

    Paint smallPaint = Paint()
      ..color = colors.smallGrid
      ..strokeWidth = 0.5;
    Paint bigPaint = Paint()
      ..color = colors.bigGrid
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
  void _drawLabel(Canvas canvas, String text) {
    TextPainter label = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: colors.label, fontSize: 11),
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
      oldDelegate.mvPerBigSquare != mvPerBigSquare ||
      oldDelegate.texts != texts ||   // e.g. the language was changed
      oldDelegate.beatMarkers != beatMarkers ||
      oldDelegate.colors != colors;   // light <-> dark theme
} // with every build() a new _EkgPainter is created, flutter asks if the new painter is goin gtoi draw something different than the previous one, if not then its skispped
// new data is taken care of by repaint: buffer, so here e compare only settings, with changing x1/x2/x4 the result is true
// covariant narrows the type of the parameter; the base class calls it a CustomPainter, covariant says its always gonna be _EkgPainter

// the colors of the chart, one set for the light and one for the dark theme
// public, so the buttons and texts lying ON the chart (full screen) can use the matching color
// ThemeExtension: our own part of the app theme, MaterialApp keeps it next to the colorScheme,
// so every chart redraws by itself when the theme changes (palette, light/dark, the switch in Settings)
class EkgChartColors extends ThemeExtension<EkgChartColors> {
  const EkgChartColors({
    required this.background,
    required this.smallGrid,
    required this.bigGrid,
    required this.line,
    required this.label,
    required this.marker,
    required this.controls,
  });

  final Color background;
  final Color smallGrid;
  final Color bigGrid;
  final Color line;       // the EKG itself
  final Color label;      // scale text in the corner
  final Color marker;     // beat triangles
  final Color controls;   // buttons and text on top of the chart

  // like printed EKG paper: light pink, red grid, black line
  static const EkgChartColors paper = EkgChartColors(
    background: Color(0xFFFFF5F5),
    smallGrid: Color(0xFFF8C8C8),
    bigGrid: Color(0xFFE88888),
    line: Colors.black,
    label: Colors.black54,
    marker: Colors.red,
    controls: Colors.black87,
  );

  // like a hospital monitor: almost black, dark green grid, bright green line,
  // does not dazzle in a dark room
  static const EkgChartColors monitor = EkgChartColors(
    background: Color(0xFF0B1410),
    smallGrid: Color(0xFF15301F),
    bigGrid: Color(0xFF235C38),
    line: Color(0xFF3DFF7A),
    label: Colors.white60,
    marker: Color(0xFFFF5252),   // a lighter red, plain red is hard to see on black
    controls: Colors.white70,
  );

  // the chart in the colors of the palette (Settings -> "EKG chart in palette colors")
  // made from the colorScheme of the theme, so it works for every palette, light and dark
  // the grid is the main color laid see-through over the background (alphaBlend)
  factory EkgChartColors.fromScheme(ColorScheme scheme) {
    bool dark = scheme.brightness == Brightness.dark;
    Color background = Color.alphaBlend(scheme.primary.withValues(alpha: 0.05), scheme.surface);
    return EkgChartColors(
      background: background,
      smallGrid: Color.alphaBlend(scheme.primary.withValues(alpha: dark ? 0.12 : 0.15), background),
      bigGrid: Color.alphaBlend(scheme.primary.withValues(alpha: dark ? 0.35 : 0.45), background),
      // light: a dark line like ink on paper, dark: the bright main color like on a monitor
      line: dark ? scheme.primary : scheme.onSurface,
      label: scheme.onSurfaceVariant,
      marker: scheme.tertiary,   // the second color of the palette, stands out from the grid
      controls: scheme.onSurface,
    );
  }

  // the set of the current theme, a theme without our extension (e.g. in a test) gets paper / monitor
  static EkgChartColors of(BuildContext context) {
    ThemeData theme = Theme.of(context);
    return theme.extension<EkgChartColors>() ??
        (theme.brightness == Brightness.dark ? monitor : paper);
  }

  // ---- needed by ThemeExtension ----

  // a copy with some colors changed (Flutter's convention, every part of a theme has it)
  @override
  EkgChartColors copyWith({
    Color? background,
    Color? smallGrid,
    Color? bigGrid,
    Color? line,
    Color? label,
    Color? marker,
    Color? controls,
  }) =>
      EkgChartColors(
        background: background ?? this.background,
        smallGrid: smallGrid ?? this.smallGrid,
        bigGrid: bigGrid ?? this.bigGrid,
        line: line ?? this.line,
        label: label ?? this.label,
        marker: marker ?? this.marker,
        controls: controls ?? this.controls,
      );

  // the colors in between two sets, t = 0..1: MaterialApp changes the theme smoothly (~200 ms),
  // so the chart fades into the new colors together with the rest of the app
  @override
  EkgChartColors lerp(EkgChartColors? other, double t) {
    if (other == null) return this;
    return EkgChartColors(
      background: Color.lerp(background, other.background, t)!,
      smallGrid: Color.lerp(smallGrid, other.smallGrid, t)!,
      bigGrid: Color.lerp(bigGrid, other.bigGrid, t)!,
      line: Color.lerp(line, other.line, t)!,
      label: Color.lerp(label, other.label, t)!,
      marker: Color.lerp(marker, other.marker, t)!,
      controls: Color.lerp(controls, other.controls, t)!,
    );
  }
}

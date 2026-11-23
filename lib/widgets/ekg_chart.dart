import 'package:flutter/foundation.dart';   // ValueListenable
import 'package:flutter/material.dart';
import '../artifact_detector.dart';   // Artifact
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
    this.eventMarkers,
    this.artifactMarkers,
    this.prematureMarkers,
    this.irregularMarkers,
  });

// final: cannot be changed after the constructor, required: must be given when creating the widget
  final EkgBuffer buffer;
  final int sampleRateHz;
  final double mvPerBigSquare;
  // optional: where the R waves are, as positions in the buffer (0 = oldest sample),
  // a small red triangle is drawn under each one; null = no markers (live chart)
  final ValueListenable<List<int>>? beatMarkers;
  // optional: marked events (the event button), positions in the buffer like beatMarkers,
  // a blue vertical line with a small flag at the top
  final ValueListenable<List<int>>? eventMarkers;
  // optional: disturbed parts found automatically, start / end as positions in the buffer
  // (they can start before the buffer or end after it), an orange band with an orange flag
  final ValueListenable<List<Artifact>>? artifactMarkers;
  // optional: the premature beats (RhythmAnalysis), positions in the buffer like beatMarkers,
  // a bigger purple triangle over the red one under that R wave
  final ValueListenable<List<int>>? prematureMarkers;
  // optional: the irregular rhythm episodes (AfDetector), (start, end) as positions in the buffer
  // like artifactMarkers, a green band with a green flag
  final ValueListenable<List<(int, int)>>? irregularMarkers;

  // blue: different from the red beat triangles, also used by the event button and the chips
  static const Color eventColor = Color(0xFF1E88E5);
  // orange: found by the app, not marked by the person
  static const Color artifactColor = Color(0xFFFB8C00);
  // purple: a found beat, but a special one (different from red beats, blue events, orange artifacts)
  static const Color prematureColor = Color(0xFF8E24AA);
  // green: a long part of the recording found by the app, like the orange artifacts
  static const Color irregularColor = Color(0xFF43A047);

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
          colors, _autoScale, widget.eventMarkers, widget.artifactMarkers, widget.prematureMarkers,
          widget.irregularMarkers),
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
      this.autoScale, this.eventMarkers, this.artifactMarkers, this.prematureMarkers, this.irregularMarkers)
      : super(repaint: Listenable.merge(
            [buffer, beatMarkers, eventMarkers, artifactMarkers, prematureMarkers, irregularMarkers]));
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
  final ValueListenable<List<int>>? eventMarkers;
  final ValueListenable<List<Artifact>>? artifactMarkers;
  final ValueListenable<List<int>>? prematureMarkers;
  final ValueListenable<List<(int, int)>>? irregularMarkers;

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

    _drawIrregular(canvas, size, pxPerSecond / sampleRateHz);
    _drawArtifacts(canvas, size, pxPerSecond / sampleRateHz);
    _drawBeatMarkers(canvas, size, pxPerSecond / sampleRateHz);
    _drawPrematureMarkers(canvas, size, pxPerSecond / sampleRateHz);
    _drawEventMarkers(canvas, size, pxPerSecond / sampleRateHz);
    String label = EkgChart.scaleLabel(texts, secondsPerBigSquare, scale);
    _drawLabel(canvas, auto ? '$label · ${texts.chartZoomAuto}' : label);
  }

  // a see-through green band over every irregular rhythm episode, a green flag where it starts
  // (drawn before the artifacts: an artifact inside an episode stays orange)
  void _drawIrregular(Canvas canvas, Size size, double xStep) {
    List<(int, int)>? episodes = irregularMarkers?.value;
    if (episodes == null || episodes.isEmpty) return;
    Paint band = Paint()..color = EkgChart.irregularColor.withValues(alpha: 0.15);
    Paint flag = Paint()..color = EkgChart.irregularColor;
    for (var (start, end) in episodes) {
      canvas.drawRect(Rect.fromLTRB(start * xStep, 0, end * xStep, size.height), band);
      if (start < 0) continue;   // started before the window: its flag is not visible
      double x = start * xStep;
      canvas.drawPath(
          Path()
            ..moveTo(x, _flagTop)
            ..lineTo(x + 10, _flagTop + 5)
            ..lineTo(x, _flagTop + 10)
            ..close(),
          flag);
    }
  }

  // a see-through orange band over every disturbed part, an orange flag where it starts
  void _drawArtifacts(Canvas canvas, Size size, double xStep) {
    List<Artifact>? artifacts = artifactMarkers?.value;
    if (artifacts == null || artifacts.isEmpty) return;
    Paint band = Paint()..color = EkgChart.artifactColor.withValues(alpha: 0.18);
    Paint flag = Paint()..color = EkgChart.artifactColor;
    for (Artifact a in artifacts) {
      canvas.drawRect(Rect.fromLTRB(a.start * xStep, 0, a.end * xStep, size.height), band);
      if (a.start < 0) continue;   // started before the window: its flag is not visible
      double x = a.start * xStep;
      canvas.drawPath(
          Path()
            ..moveTo(x, _flagTop)
            ..lineTo(x + 10, _flagTop + 5)
            ..lineTo(x, _flagTop + 10)
            ..close(),
          flag);
    }
  }

  // a blue vertical line over the whole height + a small flag for every event
  // the flag is below the scale label (top left), so the label never covers it
  static const double _flagTop = 18;

  void _drawEventMarkers(Canvas canvas, Size size, double xStep) {
    List<int>? markers = eventMarkers?.value;
    if (markers == null || markers.isEmpty) return;
    Paint line = Paint()
      ..color = EkgChart.eventColor
      ..strokeWidth = 2;
    Paint flag = Paint()..color = EkgChart.eventColor;
    for (int position in markers) {
      double x = position * xStep;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
      Path triangle = Path()
        ..moveTo(x, _flagTop)
        ..lineTo(x + 10, _flagTop + 5)
        ..lineTo(x, _flagTop + 10)
        ..close();
      canvas.drawPath(triangle, flag);
    }
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

  // a bigger purple triangle under every premature beat, it covers the red one of that beat
  void _drawPrematureMarkers(Canvas canvas, Size size, double xStep) {
    List<int>? markers = prematureMarkers?.value;
    if (markers == null || markers.isEmpty) return;
    Paint purple = Paint()..color = EkgChart.prematureColor;
    for (int position in markers) {
      double x = position * xStep;
      Path triangle = Path()
        ..moveTo(x, size.height - 16)
        ..lineTo(x - 8, size.height)
        ..lineTo(x + 8, size.height)
        ..close();
      canvas.drawPath(triangle, purple);
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
    // a background under the text: the signal or an event line under the label don't make it unreadable
    canvas.drawRect(Rect.fromLTWH(2, 1, label.width + 4, label.height + 2),
        Paint()..color = colors.background.withValues(alpha: 0.85));
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
      oldDelegate.eventMarkers != eventMarkers ||
      oldDelegate.artifactMarkers != artifactMarkers ||
      oldDelegate.prematureMarkers != prematureMarkers ||
      oldDelegate.irregularMarkers != irregularMarkers ||
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

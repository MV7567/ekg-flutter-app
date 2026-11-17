import 'dart:math';                     // min, max
import 'dart:typed_data';               // Float32List, Uint8List
import 'package:pdf/pdf.dart';          // PdfPageFormat, PdfColor, PdfGraphics
import 'package:pdf/widgets.dart' as pw; // "pw." so its Text, Row... don't mix with Flutter's
import '../l10n/app_localizations.dart';
import '../rr_stats.dart';
import '../screens/recordings_screen.dart';   // formatStart, formatDuration
import '../widgets/rr_tachogram.dart';        // the range of the tachogram

// a PDF report of one recording (A4):
//   - date, device, note, length
//   - the statistics (heart rate, HRV) and the tachogram
//   - the EKG itself in strips on "paper", like a printout of an EKG machine:
//     25 mm/s, small squares 1 mm, big squares 5 mm, red ticks under the found beats
// pure Dart (package pdf), no screen needed, so it can be tested; the fonts are passed in
class PdfReport {
  static const double paperSpeedMmPerS = 25;   // the standard EKG paper speed
  static const double stripSeconds = 6;        // 6 s x 25 mm/s = 150 mm, fits A4 with the margins
  static const double stripHeightMm = 30;      // 6 big squares
  static const int maxStrips = 10;             // 60 s of EKG, a 10 min recording would be 100 strips

  // the strips start at 0:02: in the first ~2 s after START the signal settles
  // (electrodes, input of the ADS1194: a step or a drift of 0.4..4 mV in real recordings),
  // the 0.5 Hz high-pass turns it into a big hump, which is not the heart
  static const double skipSeconds = 2;

  // amplitude in mm/mV: 10 = the standard (x1), then x2, x4, x8 like the zoom in the app
  // a lead I QRS of ~0.3 mV is only 3 mm at 10 mm/mV, so the report chooses like "Auto"
  static const List<int> gains = [10, 20, 40, 80];

  static const PdfColor _paper = PdfColor.fromInt(0xFFFFF4F4);
  static const PdfColor _smallGrid = PdfColor.fromInt(0xFFF8C8C8);
  static const PdfColor _bigGrid = PdfColor.fromInt(0xFFE88A8A);
  static const PdfColor _eventColor = PdfColor.fromInt(0xFF1E88E5);   // the same blue as in the app

  // the biggest gain where the usual beats take at most 70 % of the half height of a strip
  // usual = the median of the highest |value| of every second (one artifact doesn't count)
  static int chooseGain(Float32List millivolts, int sampleRateHz) {
    int seconds = millivolts.length ~/ sampleRateHz;
    if (seconds == 0) return gains.first;
    List<double> peaks = [];
    for (int s = 0; s < seconds; s++) {
      double peak = 0;
      for (int i = s * sampleRateHz; i < (s + 1) * sampleRateHz; i++) {
        peak = max(peak, millivolts[i].abs());
      }
      peaks.add(peak);
    }
    peaks.sort();
    double typical = peaks[peaks.length ~/ 2];
    int best = gains.first;
    for (int gain in gains) {
      if (typical * gain <= 0.7 * stripHeightMm / 2) best = gain;
    }
    return best;
  }

  // the first sample on the strips: 2 s in, but only when there is still a whole strip after it
  // (a very short recording is shown from 0:00, otherwise there would be almost nothing)
  static int firstStripSample(int samples, int sampleRateHz) {
    int skip = (skipSeconds * sampleRateHz).round();
    return samples >= skip + stripSeconds * sampleRateHz ? skip : 0;
  }

  // how many strips: the whole recording, at most 10
  static int stripCount(int samples, int sampleRateHz) =>
      min(maxStrips, (samples / (stripSeconds * sampleRateHz)).ceil());

  // the finished PDF file as bytes
  static Future<Uint8List> build({
    required AppLocalizations t,
    required pw.Font regular,
    required pw.Font bold,
    required DateTime? start,
    required String deviceName,
    required String note,
    required Float32List millivolts,   // filtered, like on the screen
    required List<int> beats,          // sample numbers of the R waves
    List<int> events = const [],       // sample numbers of the marked events
    required RrStats? stats,
    required int sampleRateHz,
  }) async {
    double mm = PdfPageFormat.mm;   // 1 mm in PDF points (1/72 inch)
    int first = firstStripSample(millivolts.length, sampleRateHz);
    // the gain only from what is on the strips, the settling hump doesn't count
    int gain = chooseGain(Float32List.sublistView(millivolts, first), sampleRateHz);
    int samplesPerStrip = (stripSeconds * sampleRateHz).round();
    int strips = stripCount(millivolts.length - first, sampleRateHz);
    int stripsEnd = min(first + strips * samplesPerStrip, millivolts.length);
    Duration length = Duration(milliseconds: (millivolts.length * 1000 / sampleRateHz).round());
    // sample number -> "0:06" for the label above a strip
    String time(int sample) =>
        RecordingsScreen.formatDuration(Duration(milliseconds: (sample * 1000 / sampleRateHz).round()));

    pw.Document doc = pw.Document(title: t.reportTitle);
    doc.addPage(pw.MultiPage(   // MultiPage: the content flows onto the next page by itself
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(15 * mm),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(t.reportDisclaimer, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          pw.Text('${context.pageNumber} / ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
      build: (context) => [
        pw.Text(t.reportTitle, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4 * mm),
        _info(t.reportStart, RecordingsScreen.formatStart(start, t)),
        _info(t.reportLength, RecordingsScreen.formatDuration(length)),
        if (deviceName.isNotEmpty) _info(t.reportDevice, deviceName),
        if (note.isNotEmpty) _info(t.reportNote, note),
        if (events.isNotEmpty) _info(t.viewEvents, events.map(time).join(', ')),
        pw.SizedBox(height: 6 * mm),

        // statistics, the same values as on the recording screen
        pw.Text(t.statsTitle, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 2 * mm),
        if (stats == null)
          pw.Text(t.statsNotEnoughBeats)
        else ...[
          pw.TableHelper.fromTextArray(
            headers: ['${t.statsMin} bpm', '${t.statsAverage} bpm', '${t.statsMax} bpm', 'SDNN', 'RMSSD'],
            data: [
              [
                '${stats.minBpm}',
                '${stats.averageBpm}',
                '${stats.maxBpm}',
                '${stats.sdnnMs.toStringAsFixed(0)} ms',
                stats.rmssdMs == null ? '--' : '${stats.rmssdMs!.toStringAsFixed(0)} ms',
              ],
            ],
            cellAlignment: pw.Alignment.center,
          ),
          pw.SizedBox(height: 1.5 * mm),
          pw.Text(t.statsBeats(stats.beatCount, stats.excludedIntervals), style: const pw.TextStyle(fontSize: 8)),
          pw.SizedBox(height: 4 * mm),
          pw.Text(t.statsTachogram),
          pw.SizedBox(height: 1.5 * mm),
          _tachogram(stats, millivolts.length / sampleRateHz, 180 * mm, 35 * mm),
          pw.SizedBox(height: 1.5 * mm),
          pw.Text(t.statsHrvHint, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        ],
        pw.SizedBox(height: 6 * mm),

        // the EKG strips
        pw.Text(t.reportEkg(paperSpeedMmPerS.round(), gain),
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        // "0:02 – 1:02 of the recording, the first 2 s are left out..."
        if (first > 0)
          pw.Text(t.reportStripsRange(time(first), time(stripsEnd), skipSeconds.round()),
              style: const pw.TextStyle(fontSize: 8)),
        pw.SizedBox(height: 2 * mm),
        // Inseparable: MultiPage never splits it (a Column alone can be split!),
        // so the time label always stays on the same page as its strip
        for (int k = 0; k < strips; k++)
          pw.Inseparable(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('${time(first + k * samplesPerStrip)} – '
                    '${time(min(first + (k + 1) * samplesPerStrip, millivolts.length))}',
                    style: const pw.TextStyle(fontSize: 8)),
                _strip(millivolts, first + k * samplesPerStrip, samplesPerStrip, beats, events, gain, sampleRateHz),
                pw.SizedBox(height: 3 * mm),
              ],
            ),
          ),
      ],
    ));
    return doc.save();
  }

  // "Start:  12.11.2026 16:25" in one line
  static pw.Widget _info(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(children: [
          pw.SizedBox(width: 30 * PdfPageFormat.mm, child: pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Expanded(child: pw.Text(value)),
        ]),
      );

  // one strip of EKG paper with the signal
  // PDF coordinates start at the BOTTOM left corner, y goes up (on the screen it goes down)
  static pw.Widget _strip(
      Float32List mv, int from, int count, List<int> beats, List<int> events, int gain, int sampleRateHz) {
    double mm = PdfPageFormat.mm;
    double width = stripSeconds * paperSpeedMmPerS * mm;
    double height = stripHeightMm * mm;
    return pw.CustomPaint(
      size: PdfPoint(width, height),
      painter: (PdfGraphics canvas, PdfPoint size) {
        // paper
        canvas
          ..setFillColor(_paper)
          ..drawRect(0, 0, width, height)
          ..fillPath();
        // small squares every 1 mm, then big squares every 5 mm on top
        _grid(canvas, width, height, 1 * mm, _smallGrid, 0.2);
        _grid(canvas, width, height, 5 * mm, _bigGrid, 0.5);

        // the signal: 0 mV in the middle, gain mm per mV, clipped to the strip
        int to = min(from + count, mv.length);
        if (to - from < 2) return;
        double xPerSample = paperSpeedMmPerS * mm / sampleRateHz;
        double y(double v) => (height / 2 + v * gain * mm).clamp(0, height);
        canvas
          ..setStrokeColor(PdfColors.black)
          ..setLineWidth(0.6)
          ..moveTo(0, y(mv[from]));
        for (int i = from + 1; i < to; i++) {
          canvas.lineTo((i - from) * xPerSample, y(mv[i]));
        }
        canvas.strokePath();

        // a blue line over the whole height at every marked event, with a small flag at the top
        canvas
          ..setStrokeColor(_eventColor)
          ..setFillColor(_eventColor)
          ..setLineWidth(0.8);
        for (int event in events) {
          if (event < from || event >= from + count) continue;
          double x = (event - from) * xPerSample;
          canvas
            ..drawLine(x, 0, x, height)
            ..strokePath()
            ..moveTo(x, height)
            ..lineTo(x + 2.5 * mm, height - 1.2 * mm)
            ..lineTo(x, height - 2.4 * mm)
            ..closePath()
            ..fillPath();
        }

        // a small red triangle at the bottom under every found beat
        canvas.setFillColor(PdfColors.red);
        for (int beat in beats) {
          if (beat < from || beat >= to) continue;
          double x = (beat - from) * xPerSample;
          canvas
            ..moveTo(x - 1.2 * mm, 0)
            ..lineTo(x + 1.2 * mm, 0)
            ..lineTo(x, 2 * mm)
            ..closePath()
            ..fillPath();
        }
      },
    );
  }

  static void _grid(PdfGraphics canvas, double width, double height, double step, PdfColor color, double lineWidth) {
    canvas
      ..setStrokeColor(color)
      ..setLineWidth(lineWidth);
    for (double x = 0; x <= width + 0.01; x += step) {
      canvas.drawLine(x, 0, x, height);
    }
    for (double y = 0; y <= height + 0.01; y += step) {
      canvas.drawLine(0, y, width, y);
    }
    canvas.strokePath();
  }

  // the tachogram like on the screen: RR in ms over the time, values on the left
  static pw.Widget _tachogram(RrStats stats, double durationSeconds, double width, double height) {
    List<RrPoint> points = stats.tachogram;
    var (low, high) = RrTachogram.range(points);   // the same scale as on the screen
    double labelWidth = 14 * PdfPageFormat.mm;
    double graphWidth = width - labelWidth;
    const pw.TextStyle small = pw.TextStyle(fontSize: 7);
    return pw.Row(children: [
      pw.SizedBox(
        width: labelWidth,
        height: height,
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('${high.round()} ms', style: small),
            pw.Text('${((low + high) / 2).round()} ms', style: small),
            pw.Text('${low.round()} ms', style: small),
          ],
        ),
      ),
      pw.CustomPaint(
        size: PdfPoint(graphWidth, height),
        painter: (PdfGraphics canvas, PdfPoint size) {
          double x(double s) => s / durationSeconds * graphWidth;
          double y(double ms) => (ms - low) / (high - low) * height;   // PDF: y goes up
          canvas
            ..setStrokeColor(PdfColors.grey400)
            ..setLineWidth(0.3);
          for (double ms in [low, (low + high) / 2, high]) {
            canvas.drawLine(0, y(ms), graphWidth, y(ms));
          }
          canvas.strokePath();
          canvas
            ..setStrokeColor(PdfColors.blue800)
            ..setLineWidth(0.8)
            ..moveTo(x(points.first.seconds), y(points.first.rrMs));
          for (RrPoint p in points.skip(1)) {
            canvas.lineTo(x(p.seconds), y(p.rrMs));
          }
          canvas.strokePath();
        },
      ),
    ]);
  }
}

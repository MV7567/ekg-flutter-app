// Validation of the QRS width (lib/qrs_width.dart) and of the QT interval (lib/qt_interval.dart)
// in milliseconds, on the PhysioNet QT Database (105 records of 15 min, 2 leads, 250 Hz like our
// device; in each record ~30 beats with the starts and ends of the waves marked by hand by a
// cardiologist, the .q1c files)
//
// usage (from the app folder):
//   dart run tool/qt_validation.dart <qtdb folder> [results.csv] [--any-t]
//   --any-t: give the QT also when the T wave is flat (the app does not, see QtInterval.minTShare)
//
// for every record:
//   the reference: the mean over the marked beats of QRS = QRS end - QRS start and of
//   QT = T end - QRS start ("(" before a beat = QRS start, ")" after it = QRS end, ")" after "t" = T end)
//   the app: lead 0, the app filters and beat detector, the regular beats in the marked part of the
//   record (+-5 s), QtSummary.analyze (the QRS on the chart signal, the T end on the zero phase one)
// the error = app - reference; the CSE study (1985) accepted for computer programs a spread (2 SD)
// of about 12 ms at the QRS end and 31 ms at the T end
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:ecg_ble_app/filters/zero_phase_filter.dart';
import 'package:ecg_ble_app/heart_rate_detector.dart';
import 'package:ecg_ble_app/qrs_width.dart';
import 'package:ecg_ble_app/qt_interval.dart';
import 'mitbih_validation.dart' hide main;

const int waveStart = 39, waveEnd = 40, tWave = 27;

class Reference {
  Reference(this.first, this.last, this.qrsMs, this.qtMs, this.beats);
  final double first, last;   // seconds, the marked part
  final double? qrsMs, qtMs;  // the means, null = not marked
  final int beats;
}

Reference? readReference(String path, double sampleRate) {
  List<Annotation> a = readAnnotations(path);
  List<double> qrs = [], qt = [];
  double? first, last;
  for (int i = 0; i < a.length; i++) {
    if (!beatCodes.contains(a[i].code)) continue;
    double t = a[i].time / sampleRate;
    first ??= t;
    last = t;
    if (i == 0 || a[i - 1].code != waveStart) continue;
    int start = a[i - 1].time;
    if (i + 1 < a.length && a[i + 1].code == waveEnd) qrs.add((a[i + 1].time - start) * 1000 / sampleRate);
    // the T wave of this beat: "t" then ")" before the next beat
    for (int j = i + 1; j < a.length && !beatCodes.contains(a[j].code); j++) {
      if (a[j].code == tWave && j + 1 < a.length && a[j + 1].code == waveEnd) {
        qt.add((a[j + 1].time - start) * 1000 / sampleRate);
        break;
      }
    }
  }
  if (first == null) return null;
  double? mean(List<double> v) => v.isEmpty ? null : v.reduce((p, q) => p + q) / v.length;
  return Reference(first, last!, mean(qrs), mean(qt), qrs.length);
}

String stats(List<double> e) {
  if (e.isEmpty) return 'n=0';
  double mean = e.reduce((a, b) => a + b) / e.length;
  double sd = sqrt(e.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / max(1, e.length - 1));
  double mae = e.map((v) => v.abs()).reduce((a, b) => a + b) / e.length;
  return 'n=${e.length}, mean error ${mean.toStringAsFixed(1)} ms, SD ${sd.toStringAsFixed(1)} ms, '
      'mean |error| ${mae.toStringAsFixed(1)} ms';
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/qt_validation.dart <qtdb folder> [results.csv]');
    exit(1);
  }
  String folder = args[0];
  List<String> names = File('$folder/RECORDS').readAsLinesSync().map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  List<double> qrsErrors = [], qtErrors = [];
  List<(double, double)> qtByT = [];   // (|T height| relative to the R height, error)
  int noQrs = 0, noQt = 0, noRef = 0;
  StringBuffer csv = StringBuffer('record,lead,ref_qrs,app_qrs,ref_qt,app_qt,rr\n');
  print('record   lead   QRS ref  app    QT ref  app    RR');
  for (String name in names) {
    if (!File('$folder/$name.q1c').existsSync()) continue;
    Header h = readHeader('$folder/$name.hea');
    Reference? ref = readReference('$folder/$name.q1c', h.sampleRate);
    if (ref == null) {
      noRef++;
      continue;
    }
    Float64List raw = resample(readLead0('$folder/$name.dat', h), h.sampleRate);
    List<double> chart = filterLikeApp(raw);
    List<double> zero = ZeroPhaseFilter.apply(raw, targetRate.toDouble());
    List<int> beats = HeartRateDetector.findBeats(chart, targetRate);
    // only the marked part, +-5 s
    List<int> part = [
      for (int b in beats) if (b / targetRate >= ref.first - 5 && b / targetRate <= ref.last + 5) b,
    ];
    List<int> intervals = [for (int k = 1; k < part.length; k++) part[k] - part[k - 1]]..sort();
    if (intervals.isEmpty) {
      noQrs++;
      continue;
    }
    double rrMs = intervals[intervals.length ~/ 2] * 1000 / targetRate;
    // exactly the app code; --any-t: also with a flat T wave (to see how much worse it is)
    QtSummary? summary = QtSummary.analyze(chart, zero, QrsWidth.regularBeats(part), rrMs, targetRate,
        minTShare: args.contains('--any-t') ? 0 : QtInterval.minTShare);
    (int, int)? qrs = summary?.qrs;
    double? appQrs = qrs == null ? null : (qrs.$2 - qrs.$1) * 1000 / targetRate;
    QtMeasurement? qt = summary?.qt;
    if (appQrs == null) noQrs++;
    if (ref.qrsMs != null && appQrs != null) qrsErrors.add(appQrs - ref.qrsMs!);
    if (ref.qtMs != null) {
      if (qt == null) {
        noQt++;
      } else {
        qtErrors.add(qt.qtMs - ref.qtMs!);
        List<double> b = summary!.beat;
        double rHeight = b.reduce(max) - b.reduce(min);
        qtByT.add((qt.tHeightMv.abs() / rHeight, qt.qtMs - ref.qtMs!));
      }
    }
    String f(double? v) => v == null ? '--' : v.toStringAsFixed(0);
    print('${name.padRight(8)} ${h.lead.padRight(6)} ${f(ref.qrsMs).padLeft(5)} ${f(appQrs).padLeft(5)}   '
        '${f(ref.qtMs).padLeft(5)} ${f(qt?.qtMs).padLeft(5)}   ${rrMs.toStringAsFixed(0)}');
    csv.writeln('$name,${h.lead},${f(ref.qrsMs)},${f(appQrs)},${f(ref.qtMs)},${f(qt?.qtMs)},${rrMs.toStringAsFixed(0)}');
  }
  print('');
  print('QRS width: ${stats(qrsErrors)}, not measured $noQrs');
  print('QT:        ${stats(qtErrors)}, not measured $noQt (of the records with a marked T end)');
  if (noRef > 0) print('records without marked beats: $noRef');
  // how good QT is when the T wave is clear: by the T height relative to the QRS height
  String robust(List<double> e) {
    if (e.isEmpty) return 'n=0';
    List<double> a = [for (double v in e) v.abs()]..sort();
    return '${stats(e)}, median |error| ${a[a.length ~/ 2].toStringAsFixed(1)} ms, '
        'within 30 ms ${(100 * a.where((v) => v <= 30).length / a.length).toStringAsFixed(0)} %, '
        'within 50 ms ${(100 * a.where((v) => v <= 50).length / a.length).toStringAsFixed(0)} %';
  }
  for (double limit in [0.0, 0.05, 0.10, 0.15, 0.20]) {
    print('QT, T >= ${(limit * 100).round()} % of QRS: ${robust([for (var (t, e) in qtByT) if (t >= limit) e])}');
  }
  List<String> files = [for (String a in args.skip(1)) if (!a.startsWith('--')) a];
  if (files.isNotEmpty) {
    File(files.first).writeAsStringSync(csv.toString());
    print('saved: ${files.first}');
  }
}

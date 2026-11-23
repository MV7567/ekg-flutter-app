// Validation of the QRS width measurement (lib/qrs_width.dart) on the MIT-BIH Arrhythmia
// Database, the same data and pipeline as tool/mitbih_validation.dart.
//
// usage (from the app folder):
//   dart run tool/qrs_validation.dart <mitdb folder> [--sweep]
//   --sweep: also every setting of the two limits (quietRatio x quietMs)
//
// MIT-BIH has no measured QRS widths, but it has the beat types, and some types are wide
// by definition (>= 120 ms): L (left bundle branch block), R (right bundle branch block),
// V (premature ventricular); N (normal) and the supraventricular A, a, J, S are usually narrow
//  A. the median beat of every type in every record (at least 5 beats): is the width on the
//     right side of 120 ms? (this checks the measurement, the beats are chosen by the annotations)
//  B. the median beat as the app chooses its beats (regular intervals, QrsWidth.regularBeats)
//  C. single premature beats (V against A a J S): wide >= 120 ms = ventricular?
// the paced records and the first 10 s are left out
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';
import 'package:ecg_ble_app/heart_rate_detector.dart';
import 'package:ecg_ble_app/qrs_width.dart';
import 'mitbih_validation.dart' hide main;

const Map<int, String> typeNames = {1: 'N', 2: 'L', 3: 'R', 5: 'V'};
const Set<int> wideTypes = {2, 3, 5};
const Set<int> supraventricularPremature = {4, 7, 8, 9};   // a J A S
const int pvc = 5;

class Rec {
  Rec(this.name, this.x, this.beats, this.types);
  final String name;
  final List<double> x;        // filtered like in the app, 250 Hz
  final List<int> beats;       // found by the app detector
  final List<int?> types;      // the annotation code of each found beat, null = no annotation near
}

String stats(List<double> v) {
  if (v.isEmpty) return 'n=0';
  double mean = v.reduce((a, b) => a + b) / v.length;
  double sd = v.length < 2 ? 0 : sqrt(v.map((e) => (e - mean) * (e - mean)).reduce((a, b) => a + b) / (v.length - 1));
  List<double> s = List.of(v)..sort();
  return 'n=${v.length}, mean ${mean.toStringAsFixed(0)} ms, SD ${sd.toStringAsFixed(0)}, '
      'median ${s[s.length ~/ 2].toStringAsFixed(0)}, range ${s.first.toStringAsFixed(0)}-${s.last.toStringAsFixed(0)}';
}

String pct(int a, int b) => b == 0 ? '--' : '${(100 * a / b).toStringAsFixed(1)} %';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/qrs_validation.dart <mitdb folder> [--sweep]');
    exit(1);
  }
  String folder = args[0];
  List<String> names = File('$folder/RECORDS').readAsLinesSync().map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  List<Rec> recs = [];
  for (String name in names) {
    if (pacedRecords.contains(name)) continue;
    Header h = readHeader('$folder/$name.hea');
    List<double> x = filterLikeApp(resample(readLead0('$folder/$name.dat', h), h.sampleRate));
    List<int> beats = [for (int b in HeartRateDetector.findBeats(x, targetRate)) if (b >= skipSeconds * targetRate) b];
    List<Annotation> ann = [for (Annotation a in readAnnotations('$folder/$name.atr')) if (beatCodes.contains(a.code)) a];
    // every found beat gets the type of the nearest annotated beat within 150 ms
    List<int?> types = [];
    int j = 0;
    for (int b in beats) {
      double t = b / targetRate;
      while (j + 1 < ann.length && ann[j + 1].time / h.sampleRate <= t) {
        j++;
      }
      int? best;
      double bestD = matchWindowSeconds;
      for (int k = max(0, j - 1); k <= min(ann.length - 1, j + 1); k++) {
        double d = (ann[k].time / h.sampleRate - t).abs();
        if (d <= bestD) {
          bestD = d;
          best = ann[k].code;
        }
      }
      types.add(best);
    }
    recs.add(Rec(name, x, beats, types));
    stdout.write('.');
  }
  print('');

  void run(double ratio, {double quiet = QrsWidth.quietMs, bool details = false}) {
    print('');
    print('=== quiet limit ${(ratio * 100).round()} % of the steepest slope, flat for ${quiet.round()} ms ===');

    // A. the median beat of every type, per record
    Map<int, List<double>> byType = {for (int t in typeNames.keys) t: []};
    int failedA = 0;
    StringBuffer table = StringBuffer();
    for (Rec r in recs) {
      List<String> cells = [];
      for (int t in typeNames.keys) {
        List<int> chosen = [for (int k = 0; k < r.beats.length; k++) if (r.types[k] == t) r.beats[k]];
        if (chosen.length < QrsWidth.minBeats) continue;
        double? w = QrsWidth.typicalMs(r.x, chosen, targetRate, quietRatio: ratio, quietMs: quiet);
        if (w == null) {
          failedA++;
          continue;
        }
        byType[t]!.add(w);
        cells.add('${typeNames[t]} ${w.toStringAsFixed(0)} ms (${chosen.length})');
      }
      table.writeln('${r.name}: ${cells.join(', ')}');
    }
    if (details) print(table.toString().trimRight());
    print('A. median beat per type and record (not measurable: $failedA):');
    for (int t in typeNames.keys) {
      List<double> w = byType[t]!;
      int wide = w.where((v) => v >= QrsWidth.wideMs).length;
      print('   ${typeNames[t]}: ${stats(w)}, >= 120 ms: ${pct(wide, w.length)}'
          '${wideTypes.contains(t) ? ' (should be wide)' : ' (should be narrow)'}');
    }
    int correct = 0, total = 0;
    for (int t in typeNames.keys) {
      for (double w in byType[t]!) {
        total++;
        if ((w >= QrsWidth.wideMs) == wideTypes.contains(t)) correct++;
      }
    }
    print('   wide / narrow right: $correct of $total = ${pct(correct, total)}');

    // B. the median beat as the app chooses it, against the main type of the record
    List<double> appNarrow = [], appWide = [];
    for (Rec r in recs) {
      List<int> regular = QrsWidth.regularBeats(r.beats);
      double? w = QrsWidth.typicalMs(r.x, regular, targetRate, quietRatio: ratio, quietMs: quiet);
      if (w == null) continue;
      // the type most of the regular beats have
      Map<int, int> count = {};
      for (int k = 0; k < r.beats.length; k++) {
        if (regular.contains(r.beats[k]) && r.types[k] != null) count[r.types[k]!] = (count[r.types[k]!] ?? 0) + 1;
      }
      if (count.isEmpty) continue;
      int main = count.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      (wideTypes.contains(main) ? appWide : appNarrow).add(w);
      if (details) print('   ${r.name}: app median beat ${w.toStringAsFixed(0)} ms, mostly ${typeNames[main] ?? main}');
    }
    print('B. app median beat: records mostly N: ${stats(appNarrow)}, '
        '>= 120 ms ${pct(appNarrow.where((v) => v >= QrsWidth.wideMs).length, appNarrow.length)}');
    print('   records mostly L/R: ${stats(appWide)}, '
        '>= 120 ms ${pct(appWide.where((v) => v >= QrsWidth.wideMs).length, appWide.length)}');

    // C. single premature beats
    List<double> v = [], sv = [];
    int notMeasured = 0;
    for (Rec r in recs) {
      for (int k = 0; k < r.beats.length; k++) {
        int? t = r.types[k];
        if (t != pvc && !supraventricularPremature.contains(t)) continue;
        double? w = QrsWidth.widthMs(r.x, r.beats[k], targetRate, quietRatio: ratio, quietMs: quiet);
        if (w == null) {
          notMeasured++;
          continue;
        }
        (t == pvc ? v : sv).add(w);
      }
    }
    int vWide = v.where((w) => w >= QrsWidth.wideMs).length;
    int svNarrow = sv.where((w) => w < QrsWidth.wideMs).length;
    print('C. single beats: V ${stats(v)}');
    print('   A/a/J/S ${stats(sv)}  (not measurable: $notMeasured)');
    print('   V wide (Se) ${pct(vWide, v.length)}, A/a/J/S narrow (Sp) ${pct(svNarrow, sv.length)}');
  }

  bool sweep = args.contains('--sweep');
  run(QrsWidth.quietRatio, details: !sweep);
  if (sweep) {
    for (double quiet in [12, 16, 20]) {
      for (double ratio in [0.04, 0.06, 0.08, 0.10]) {
        run(ratio, quiet: quiet);
      }
    }
  }
}

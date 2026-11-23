// Validation of the premature beat finder with the beat shape (lib/beat_shape.dart) on the
// MIT-BIH Arrhythmia Database, the same data, pipeline and reference as tool/premature_validation.dart
//
// usage (from the app folder):
//   dart run tool/shape_validation.dart <mitdb folder>
//
// for every found beat: the timing rule of RhythmAnalysis (premature in time), the correlation
// with the median beat, the height ratio and the QRS width against the typical one
// (the median beat made like in the app: QrsSummary without the premature beats)
//  1. how the measures look for the beat types (N, V, supraventricular premature S)
//  2. the rules: "timing only" against "timing OR a different shape", Se / +P of the premature
//     beats (reference: a V J A S), and how many V of them are called ventricular
//  3. the app as it is (RhythmAnalysis.analyze with the signal): the premature and ventricular
//     beats, the ventricular beats in a row (reference: V annotations one after the other) and
//     the pauses (reference: two annotated beats >= 2 s apart; this one also inside AF)
// the paced records, the AF / flutter episodes and the first 10 s are left out
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';
import 'package:ecg_ble_app/beat_shape.dart';
import 'package:ecg_ble_app/heart_rate_detector.dart';
import 'package:ecg_ble_app/qrs_width.dart';
import 'package:ecg_ble_app/rhythm_analysis.dart';
import 'mitbih_validation.dart' hide main;

const Set<int> prematureCodes = {4, 5, 7, 8, 9};   // a V J A S
const int pvc = 5;
const Set<String> fibrillation = {'(AFIB', '(AFL'};

class BeatInfo {
  BeatInfo(this.type, this.timing, this.correlation, this.ratio, this.widthMs, this.typicalMs, this.earliness);
  final int? type;              // the annotation code, null = no annotation near (a false detection)
  final bool timing;            // premature by the timing rule
  final double? correlation;    // null = no median beat / too close to the edge
  final double? ratio;
  final double? widthMs;
  final double? typicalMs;
  final double? earliness;      // the interval before the beat / the median of the 8 before it
  bool get premature => prematureCodes.contains(type);
}

String pct(num a, num b) => b == 0 ? '--' : '${(100 * a / b).toStringAsFixed(1)} %';

String describe(List<double> v) {
  if (v.isEmpty) return 'n=0';
  v.sort();
  String q(double p) => v[(p * (v.length - 1)).round()].toStringAsFixed(2);
  return 'n=${v.length}, 10 % ${q(0.1)}, median ${q(0.5)}, 90 % ${q(0.9)}';
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/shape_validation.dart <mitdb folder>');
    exit(1);
  }
  String folder = args[0];
  List<String> names = File('$folder/RECORDS').readAsLinesSync().map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  List<BeatInfo> all = [];
  // 3. the app: counters
  int appTp = 0, appFp = 0, appRef = 0, appV = 0, appVFound = 0, appVCalled = 0, appSFound = 0, appSCalledV = 0;
  int runRef = 0, runRefFound = 0, runFound = 0, runFoundTrue = 0;
  int runRef3 = 0, runRef3Found = 0;
  int pauseRef = 0, pauseRefFound = 0, pauseFound = 0, pauseFoundTrue = 0;
  for (String name in names) {
    if (pacedRecords.contains(name)) continue;
    Header h = readHeader('$folder/$name.hea');
    List<double> x = filterLikeApp(resample(readLead0('$folder/$name.dat', h), h.sampleRate));
    List<int> beats = HeartRateDetector.findBeats(x, targetRate);
    List<Annotation> annotations = readAnnotations('$folder/$name.atr');
    List<Annotation> ann = [for (Annotation a in annotations) if (beatCodes.contains(a.code)) a];
    bool inFibrillation(double t) {
      String rhythm = '';
      for (Annotation a in annotations) {
        if (a.time / h.sampleRate > t) break;
        rhythm = a.rhythm;
      }
      return fibrillation.contains(rhythm);
    }

    List<int> timing = RhythmAnalysis.findPremature(beats, targetRate);
    Set<int> timingSet = timing.toSet();
    QrsSummary qrs = QrsSummary.analyze(x, beats, targetRate, premature: timing);
    double? typical = qrs.typicalMs(targetRate);

    int j = 0;
    for (int index = 0; index < beats.length; index++) {
      int b = beats[index];
      double? earliness;
      if (index >= 9) {
        List<int> previous = [for (int k = index - 8; k < index; k++) beats[k] - beats[k - 1]]..sort();
        earliness = (beats[index] - beats[index - 1]) / previous[4];
      }
      double t = b / targetRate;
      while (j + 1 < ann.length && ann[j + 1].time / h.sampleRate <= t) {
        j++;
      }
      int? type;
      double bestD = matchWindowSeconds;
      for (int k = max(0, j - 1); k <= min(ann.length - 1, j + 1); k++) {
        double d = (ann[k].time / h.sampleRate - t).abs();
        if (d <= bestD) {
          bestD = d;
          type = ann[k].code;
        }
      }
      if (t < skipSeconds || inFibrillation(t)) continue;
      List<double>? template = qrs.medianBeat;
      all.add(BeatInfo(
        type,
        timingSet.contains(b),
        template == null ? null : BeatShape.correlation(x, b, template, qrs.r, targetRate),
        template == null ? null : BeatShape.heightRatio(x, b, template, qrs.r, targetRate),
        QrsWidth.widthMs(x, b, targetRate),
        typical,
        earliness,
      ));
    }
    // 3. the app as it is
    RhythmAnalysis app = RhythmAnalysis.analyze(beats, targetRate, 70, signal: x);
    Set<int> appPremature = app.prematureBeats.toSet();
    int jj = 0;
    for (int b in beats) {
      double t = b / targetRate;
      while (jj + 1 < ann.length && ann[jj + 1].time / h.sampleRate <= t) {
        jj++;
      }
      int? type;
      double bestD = matchWindowSeconds;
      for (int k = max(0, jj - 1); k <= min(ann.length - 1, jj + 1); k++) {
        double d = (ann[k].time / h.sampleRate - t).abs();
        if (d <= bestD) {
          bestD = d;
          type = ann[k].code;
        }
      }
      if (t < skipSeconds || inFibrillation(t)) continue;
      bool found = appPremature.contains(b);
      bool isPremature = prematureCodes.contains(type);
      if (found && isPremature) appTp++;
      if (found && !isPremature) appFp++;
      if (type == pvc && found) {
        appVFound++;
        if (app.ventricular.contains(b)) appVCalled++;
      }
      if (isPremature && type != pvc && found) {
        appSFound++;
        if (app.ventricular.contains(b)) appSCalledV++;
      }
    }
    // the reference counts: all annotated premature beats outside AF, after 10 s
    for (Annotation a in ann) {
      double t = a.time / h.sampleRate;
      if (t < skipSeconds || inFibrillation(t)) continue;
      if (prematureCodes.contains(a.code)) appRef++;
      if (a.code == pvc) appV++;
    }
    // ventricular beats in a row: (start s, end s) of the reference and of the app
    List<(double, double, int)> refRuns = [];
    List<Annotation> current = [];
    void close() {
      if (current.length >= 2) {
        double a = current.first.time / h.sampleRate, b = current.last.time / h.sampleRate;
        if (a >= skipSeconds && !inFibrillation(a)) refRuns.add((a, b, current.length));
      }
      current = [];
    }
    for (Annotation a in ann) {
      if (a.code == pvc) {
        current.add(a);
      } else {
        close();
      }
    }
    close();
    List<(double, double)> appRuns = [
      for (List<int> r in app.runs)
        if (r.first / targetRate >= skipSeconds && !inFibrillation(r.first / targetRate))
          (r.first / targetRate, r.last / targetRate),
    ];
    bool overlap(double a0, double a1, double b0, double b1) =>
        a0 <= b1 + matchWindowSeconds && b0 <= a1 + matchWindowSeconds;
    for (var (a, b, n) in refRuns) {
      bool hit = appRuns.any((r) => overlap(a, b, r.$1, r.$2));
      runRef++;
      if (hit) runRefFound++;
      if (n >= 3) {
        runRef3++;
        if (hit) runRef3Found++;
      }
    }
    for (var (a, b) in appRuns) {
      runFound++;
      if (refRuns.any((r) => overlap(a, b, r.$1, r.$2))) runFoundTrue++;
    }
    // pauses
    List<(double, double)> refPauses = [
      for (int k = 1; k < ann.length; k++)
        if (ann[k - 1].time / h.sampleRate >= skipSeconds &&
            (ann[k].time - ann[k - 1].time) / h.sampleRate >= RhythmAnalysis.pauseSeconds)
          (ann[k - 1].time / h.sampleRate, ann[k].time / h.sampleRate),
    ];
    List<(double, double)> appPauses = [
      for (var (a, b) in app.pauses) if (a / targetRate >= skipSeconds) (a / targetRate, b / targetRate),
    ];
    for (var (a, b) in refPauses) {
      pauseRef++;
      if (appPauses.any((p) => overlap(a, b, p.$1, p.$2))) pauseRefFound++;
    }
    for (var (a, b) in appPauses) {
      pauseFound++;
      if (refPauses.any((p) => overlap(a, b, p.$1, p.$2))) pauseFoundTrue++;
    }
    stdout.write('.');
  }
  print('');

  // 1. the measures per type
  print('1. correlation with the median beat:');
  print('   N: ${describe([for (BeatInfo b in all) if (b.type == 1 && b.correlation != null) b.correlation!])}');
  print('   V: ${describe([for (BeatInfo b in all) if (b.type == pvc && b.correlation != null) b.correlation!])}');
  print('   A/a/J/S: ${describe([for (BeatInfo b in all) if (prematureCodes.contains(b.type) && b.type != pvc && b.correlation != null) b.correlation!])}');
  print('   height ratio N: ${describe([for (BeatInfo b in all) if (b.type == 1 && b.ratio != null) b.ratio!])}');
  print('   height ratio V: ${describe([for (BeatInfo b in all) if (b.type == pvc && b.ratio != null) b.ratio!])}');
  print('   beats without a median beat in their record: ${all.where((b) => b.correlation == null).length} of ${all.length}');

  // 2. the rules
  int reference = all.where((b) => b.premature).length;
  int referenceV = all.where((b) => b.type == pvc).length;
  print('');
  print('2. premature beats: $reference in the reference, of them V $referenceV');
  print('   rule                                      Se       +P      V found   V called ventricular');
  void rule(String name, bool Function(BeatInfo) different) {
    bool found(BeatInfo b) => b.timing || different(b);
    int tp = all.where((b) => found(b) && b.premature).length;
    int fp = all.where((b) => found(b) && !b.premature).length;
    int vFound = all.where((b) => found(b) && b.type == pvc).length;
    // ventricular = a different shape, or a wide QRS
    int vCalled = all.where((b) => found(b) && b.type == pvc &&
        (different(b) || (b.widthMs ?? 0) >= QrsWidth.wideMs)).length;
    int sFound = all.where((b) => found(b) && b.premature && b.type != pvc).length;
    int sCalledV = all.where((b) => found(b) && b.premature && b.type != pvc &&
        (different(b) || (b.widthMs ?? 0) >= QrsWidth.wideMs)).length;
    print('   ${name.padRight(40)} ${pct(tp, reference).padLeft(7)}  ${pct(tp, tp + fp).padLeft(7)}  '
        '${pct(vFound, referenceV).padLeft(7)}   V ${pct(vCalled, vFound)}, S called V ${pct(sCalledV, sFound)}');
  }

  rule('timing only (step 1)', (b) => false);
  // the false alarms of "corr < 0.8" by type
  Map<String, int> falseByType = {};
  for (BeatInfo b in all) {
    if (!b.timing && b.correlation != null && b.correlation! < 0.8 && !b.premature) {
      String key = b.type == null ? 'no beat' : '${b.type}';
      falseByType[key] = (falseByType[key] ?? 0) + 1;
    }
  }
  print('   false alarms of corr < 0.8 by annotation code: $falseByType');
  for (double e in [1.0, 0.95, 0.9]) {
    for (double c in [0.7, 0.8]) {
      rule('timing OR (corr < $c AND earliness < $e)', (b) =>
          b.correlation != null && b.correlation! < c && b.earliness != null && b.earliness! < e);
    }
  }
  for (double c in [0.70, 0.80, 0.85, 0.90]) {
    rule('timing OR corr < $c', (b) => b.correlation != null && b.correlation! < c);
  }
  for (double c in [0.80, 0.85]) {
    for (double k in [1.6, 2.0]) {
      rule('timing OR corr < $c OR height x$k', (b) =>
          b.correlation != null && (b.correlation! < c || b.ratio! > k || b.ratio! < 1 / k));
    }
    for (double w in [30, 40]) {
      rule('timing OR corr < $c OR width +$w ms', (b) =>
          b.correlation != null && (b.correlation! < c ||
              (b.widthMs != null && b.typicalMs != null && b.widthMs! >= b.typicalMs! + w)));
    }
  }

  print('');
  print('3. the app (RhythmAnalysis.analyze with the signal):');
  print('   premature beats: $appRef reference, Se ${pct(appTp, appRef)}, +P ${pct(appTp, appTp + appFp)}');
  print('   V found ${pct(appVFound, appV)}; called ventricular: V ${pct(appVCalled, appVFound)}, '
      'A/a/J/S ${pct(appSCalledV, appSFound)}');
  print('   ventricular in a row (reference >= 2 V): $runRef, found ${pct(runRefFound, runRef)}; '
      'of them >= 3 V: $runRef3, found ${pct(runRef3Found, runRef3)}; app groups $runFound, true ${pct(runFoundTrue, runFound)}');
  print('   pauses >= ${RhythmAnalysis.pauseSeconds} s: reference $pauseRef, found ${pct(pauseRefFound, pauseRef)}; '
      'app $pauseFound, true ${pct(pauseFoundTrue, pauseFound)}');
}

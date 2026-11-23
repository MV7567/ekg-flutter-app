// Validation of the atrial fibrillation suspicion (lib/af_detector.dart) on the MIT-BIH
// Arrhythmia Database, the same data and pipeline as tool/mitbih_validation.dart.
//
// usage (from the app folder):
//   dart run tool/af_validation.dart <mitdb folder>
//
// the reference: the rhythm annotations of the cardiologists, "(AFIB" = atrial fibrillation;
// atrial flutter "(AFL" is left out of the window count (usually a regular rhythm, not looked for)
//  A. every window of 30 intervals: AF (at least half of its time in AFIB) or not,
//     against irregularity > limit -> Se and Sp of the windows, for several limits
//  B. the episodes (>= 30 s) of the app: AF time found / all AF time (Se),
//     found time that really was AF (+P), and the false time in the records without AF
// the paced records and the first 10 s are left out
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';
import 'package:ecg_ble_app/af_detector.dart';
import 'package:ecg_ble_app/heart_rate_detector.dart';
import 'mitbih_validation.dart' hide main;

// the beat types that are premature (a V J A S), for the split of the records without AF
const Set<int> prematureCodes = {4, 5, 7, 8, 9};
const double frequentPremature =
    0.10; // >= 10 % of the beats premature = "very frequent"

class Rec {
  Rec(
    this.name,
    this.beats,
    this.segments,
    this.seconds,
    this.prematureFraction,
  );
  final String name;
  final List<int> beats; // found by the app detector, 250 Hz
  final List<(double, double, String)> segments; // (start s, end s, rhythm)
  final double seconds;
  final double prematureFraction; // of all annotated beats

  String rhythmAt(double t) {
    for (var (s, e, r) in segments) {
      if (t >= s && t < e) return r;
    }
    return '';
  }

  // seconds of [a, b) spent in this rhythm
  double timeIn(String rhythm, double a, double b) {
    double sum = 0;
    for (var (s, e, r) in segments) {
      if (r == rhythm) sum += max(0, min(b, e) - max(a, s));
    }
    return sum;
  }
}

String pct(num a, num b) =>
    b == 0 ? '--' : '${(100 * a / b).toStringAsFixed(1)} %';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/af_validation.dart <mitdb folder>');
    exit(1);
  }
  String folder = args[0];
  List<String> names = File(
    '$folder/RECORDS',
  ).readAsLinesSync().map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  List<Rec> recs = [];
  for (String name in names) {
    if (pacedRecords.contains(name)) continue;
    Header h = readHeader('$folder/$name.hea');
    List<double> x = filterLikeApp(
      resample(readLead0('$folder/$name.dat', h), h.sampleRate),
    );
    List<int> beats = [
      for (int b in HeartRateDetector.findBeats(x, targetRate))
        if (b >= skipSeconds * targetRate) b,
    ];
    double seconds = h.samples / h.sampleRate;
    // the rhythm segments from the rhythm changes
    List<(double, double, String)> segments = [];
    String current = '';
    double from = 0;
    for (Annotation a in readAnnotations('$folder/$name.atr')) {
      // its rhythm is the previous one, the next annotation has the new
      if (a.code == rhythmCode) continue;
      if (a.rhythm != current) {
        double t = a.time / h.sampleRate;
        if (current.isNotEmpty) segments.add((from, t, current));
        current = a.rhythm;
        from = t;
      }
    }
    if (current.isNotEmpty) segments.add((from, seconds, current));
    List<Annotation> beatAnnotations = [
      for (Annotation a in readAnnotations('$folder/$name.atr'))
        if (beatCodes.contains(a.code)) a,
    ];
    double premature =
        beatAnnotations.where((a) => prematureCodes.contains(a.code)).length /
        beatAnnotations.length;
    recs.add(Rec(name, beats, segments, seconds, premature));
    stdout.write('.');
  }
  print('');

  // A. the windows
  print(
    'A. windows of ${AfDetector.windowIntervals} intervals (AFL windows left out):',
  );
  // irregularity of every window, with its reference
  for (int lags in [1, AfDetector.maxLag]) {
    List<(double, bool)> windows = [];
    for (Rec r in recs) {
      for (
        int first = 0;
        first + AfDetector.windowIntervals < r.beats.length;
        first++
      ) {
        double a = r.beats[first] / targetRate,
            b = r.beats[first + AfDetector.windowIntervals] / targetRate;
        if (r.timeIn('(AFL', a, b) > 0) continue;
        double? v = AfDetector.irregularity(
          r.beats,
          first,
          targetRate,
          maxLag: lags,
        );
        if (v == null) continue;
        windows.add((v, r.timeIn('(AFIB', a, b) >= 0.5 * (b - a)));
      }
    }
    int afWindows = windows.where((w) => w.$2).length;
    print(
      '   lag 1${lags > 1 ? '..$lags (the app)' : ' only (neighbours)'}: $afWindows AF windows, ${windows.length - afWindows} other',
    );
    print('   limit    Se (AF windows found)   Sp (other windows not flagged)');
    for (double limit in [
      0.04,
      0.05,
      0.06,
      0.07,
      0.08,
      0.09,
      0.10,
      0.12,
      0.14,
    ]) {
      int tp = windows.where((w) => w.$2 && w.$1 > limit).length;
      int tn = windows.where((w) => !w.$2 && w.$1 <= limit).length;
      print(
        '   ${limit.toStringAsFixed(2)}     ${pct(tp, afWindows).padLeft(8)}                ${pct(tn, windows.length - afWindows).padLeft(8)}'
        '${limit == AfDetector.irregularLimit ? '   <- the app limit' : ''}',
      );
    }
  }

  // B. the episodes, for the app limit and one lower and one higher
  // the records without AF are split by how many premature beats they have: in a record with
  // very frequent premature beats an "irregular rhythm" message is a reason to see a doctor too
  for (double limit in [0.08, AfDetector.irregularLimit, 0.12]) {
    print('');
    print(
      'B. episodes >= ${AfDetector.minEpisodeSeconds.round()} s, limit $limit'
      '${limit == AfDetector.irregularLimit ? ' (the app)' : ''}:',
    );
    bool details = limit == AfDetector.irregularLimit;
    if (details) {
      print('record  AF time   found  found AF   false (s)   premature beats');
    }
    double allAf = 0, allFound = 0, allFoundAf = 0, allFoundAfib = 0;
    int recordsAf = 0, recordsAfFound = 0;
    // [few premature beats, many]: records, flagged records, false seconds, seconds
    List<int> records = [0, 0], flagged = [0, 0];
    List<double> falseTime = [0, 0], time = [0, 0];
    for (Rec r in recs) {
      AfDetector d = AfDetector.analyze(r.beats, targetRate, limit: limit);
      double af = r.timeIn('(AFIB', skipSeconds, r.seconds);
      double found = 0, foundAf = 0, foundAfib = 0;
      for (var (s, e) in d.episodes) {
        double a = s / targetRate, b = e / targetRate;
        found += b - a;
        foundAfib += r.timeIn('(AFIB', a, b);
        foundAf +=
            r.timeIn('(AFIB', a, b) +
            r.timeIn('(AFL', a, b); // flutter found = not a false alarm
      }
      allAf += af;
      allFound += found;
      allFoundAf += foundAf;
      allFoundAfib += foundAfib;
      if (af >= AfDetector.minEpisodeSeconds) {
        recordsAf++;
        if (d.suspected) recordsAfFound++;
      } else if (r.timeIn('(AFL', 0, r.seconds) == 0) {
        int group = r.prematureFraction < frequentPremature ? 0 : 1;
        records[group]++;
        if (d.suspected) flagged[group]++;
        falseTime[group] += found;
        time[group] += r.seconds - skipSeconds;
      }
      if (details && (af > 0 || found > 0)) {
        print(
          '${r.name.padRight(6)} ${af.toStringAsFixed(0).padLeft(7)} ${found.toStringAsFixed(0).padLeft(7)} '
          '${foundAf.toStringAsFixed(0).padLeft(9)} ${(found - foundAf).toStringAsFixed(0).padLeft(7)}'
          '       ${pct(r.prematureFraction, 1)}',
        );
      }
    }
    print(
      '   AF time found (Se): ${pct(allFoundAfib, allAf)}, '
      'found time that was AF or flutter (+P): ${pct(allFoundAf, allFound)}',
    );
    print(
      '   records with AF (>= 30 s): $recordsAfFound of $recordsAf suspected',
    );
    print(
      '   records without AF, premature beats < ${(frequentPremature * 100).round()} %: '
      '${flagged[0]} of ${records[0]} with a false episode, false time ${pct(falseTime[0], time[0])}',
    );
    print(
      '   records without AF, premature beats >= ${(frequentPremature * 100).round()} %: '
      '${flagged[1]} of ${records[1]} flagged, flagged time ${pct(falseTime[1], time[1])}',
    );
  }
}

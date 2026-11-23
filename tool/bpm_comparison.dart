// Heart rate from the EKG compared with the pulse counted by hand and with a watch.
//
// usage (from the app folder):
//   dart run tool/bpm_comparison.dart <plan.csv> <results.csv>
//
// plan.csv: one line per measurement, filled in by hand, separated by ";" or ",":
//   file;state;manual_count;watch_bpm;note
//   ekg_2026-11-23_10-00-00.csv;sitting;72;74;
//   - file: the recording (a full path, or relative to the folder of plan.csv)
//   - manual_count: pulse beats counted by hand between the two event marks (~60 s)
//   - watch_bpm: what the watch showed at the second event mark (empty = no watch)
// in every recording the FIRST TWO event marks are the start and the end of the counting
// (only one mark: the counting ended with STOP, the end of the recording is the end of the window)
//
// for every measurement, all in the same window between the two marks:
//   ecg_count  = R waves found by the app detector in the window
//   ecg_bpm    = ecg_count scaled to 1 minute (window length from the marks)
//   ecg_rr_bpm = 60 / mean RR interval of the beats in the window
//   manual_bpm = manual_count scaled to 1 minute the same way
// then for every pair of methods: bias (mean difference), SD of the differences,
// 95 % limits of agreement (bias +- 1.96 SD, Bland & Altman 1986) and MAE
//
// the recording is read here again (the app parser needs Flutter), the filters and
// the detector are exactly the app ones
// a command line tool: the results are printed
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';
import 'package:ecg_ble_app/filters/biquad_filter.dart';
import 'package:ecg_ble_app/filters/spike_remover.dart';
import 'package:ecg_ble_app/heart_rate_detector.dart';

const int sampleRate = 250;
const double millivoltsPerLsb = 2.4 / 32767 / 12 * 1000;   // the same as ekg_config.dart

class Recording {
  Recording(this.millivolts, this.events, this.lostSamples);
  final List<double> millivolts;   // index = sample number, gaps filled with the last value
  final List<int> events;          // sample numbers of the event marks
  final List<int> lostSamples;     // sample numbers that were missing (lost BLE packets)
}

// the same rules as RecordingInfo.parseMillivolts / parseEvents in the app
Recording readRecording(String path) {
  List<double> mv = [];
  List<int> events = [];
  List<int> lost = [];
  bool rawOnly = false;
  for (String line in File(path).readAsLinesSync()) {
    if (line.trim() == 'sample,raw') rawOnly = true;
    if (line.startsWith('# event:')) {
      int? e = int.tryParse(line.substring('# event:'.length).trim());
      if (e != null) events.add(e);
      continue;
    }
    List<String> c = line.split(',');
    if (c.length < (rawOnly ? 2 : 3)) continue;
    int? sample = int.tryParse(c[0]);
    if (sample == null) continue;
    double? value = !rawOnly && c.length >= 4 ? double.tryParse(c[3]) : null;
    if (value == null) {
      int? raw = int.tryParse(c[rawOnly ? 1 : 2]);
      if (raw == null) continue;
      value = raw * millivoltsPerLsb;
    }
    if (sample < mv.length) continue;
    double fill = mv.isEmpty ? value : mv.last;
    while (mv.length < sample) {
      lost.add(mv.length);
      mv.add(fill);
    }
    mv.add(value);
  }
  return Recording(mv, events, lost);
}

List<int> findBeats(List<double> mv) {
  EkgDisplayFilter filter = EkgDisplayFilter(sampleRate.toDouble());
  SpikeRemover spikes = SpikeRemover();
  return HeartRateDetector.findBeats([for (double x in mv) filter.process(spikes.process(x))], sampleRate);
}

class Measurement {
  Measurement(this.file, this.state, this.windowSeconds, this.ecgCount, this.ecgRrBpm, this.manualCount,
      this.watchBpm, this.lostInWindow, this.note);
  final String file, state, note;
  final double windowSeconds;
  final int ecgCount;
  final double? ecgRrBpm;
  final int? manualCount;
  final double? watchBpm;
  final int lostInWindow;
  double get ecgBpm => ecgCount * 60 / windowSeconds;
  double? get manualBpm => manualCount == null ? null : manualCount! * 60 / windowSeconds;
}

// one pair of methods: a - b for every measurement that has both
void agreement(String name, List<Measurement> ms, double? Function(Measurement) a, double? Function(Measurement) b) {
  List<double> d = [
    for (Measurement m in ms)
      if (a(m) != null && b(m) != null) a(m)! - b(m)!,
  ];
  if (d.length < 2) {
    print('$name: too few measurements (${d.length})');
    return;
  }
  double bias = d.reduce((x, y) => x + y) / d.length;
  double sd = sqrt(d.map((x) => (x - bias) * (x - bias)).reduce((x, y) => x + y) / (d.length - 1));
  double mae = d.map((x) => x.abs()).reduce((x, y) => x + y) / d.length;
  String f(double x) => x.toStringAsFixed(2);
  print('$name (n = ${d.length}): bias ${f(bias)} bpm, SD ${f(sd)}, '
      '95 % limits of agreement ${f(bias - 1.96 * sd)} .. ${f(bias + 1.96 * sd)} bpm, MAE ${f(mae)} bpm');
}

void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln('usage: dart run tool/bpm_comparison.dart <plan.csv> <results.csv>');
    exit(1);
  }
  File plan = File(args[0]);
  String folder = plan.parent.path;
  List<Measurement> ms = [];

  for (String line in plan.readAsLinesSync().skip(1)) {   // the 1st line = column names
    if (line.trim().isEmpty) continue;
    List<String> c = line.split(line.contains(';') ? ';' : ',').map((s) => s.trim()).toList();
    while (c.length < 5) {
      c.add('');
    }
    String path = File(c[0]).isAbsolute ? c[0] : '$folder${Platform.pathSeparator}${c[0]}';
    if (!File(path).existsSync()) {
      print('SKIPPED, no file: $path');
      continue;
    }
    Recording rec = readRecording(path);
    if (rec.events.isEmpty) {
      print('SKIPPED, no event mark: ${c[0]}');
      continue;
    }
    if (rec.events.length > 2) print('note: ${c[0]} has ${rec.events.length} marks, the first two are used');
    // only one mark: the counting ended with STOP, the window ends with the recording
    if (rec.events.length == 1) print('note: ${c[0]} has only 1 mark, the window ends at the end of the recording (STOP)');
    int from = rec.events[0];
    int to = rec.events.length >= 2 ? rec.events[1] : rec.millivolts.length;
    List<int> beats = findBeats(rec.millivolts).where((b) => b >= from && b < to).toList();
    double? rrBpm = beats.length >= 2 ? 60 * (beats.length - 1) / ((beats.last - beats.first) / sampleRate) : null;
    int lost = rec.lostSamples.where((s) => s >= from && s < to).length;
    // a missed beat = one RR interval about twice as long as the others, an extra one = a very short one
    List<int> rr = [for (int k = 1; k < beats.length; k++) beats[k] - beats[k - 1]];
    if (rr.isNotEmpty) {
      List<int> sorted = List.of(rr)..sort();
      int median = sorted[sorted.length ~/ 2];
      print('${c[0]}: RR ${(sorted.first / sampleRate).toStringAsFixed(3)} .. ${(sorted.last / sampleRate).toStringAsFixed(3)} s, '
          'median ${(median / sampleRate).toStringAsFixed(3)} s');
      if (sorted.last > 1.6 * median) print('   WARNING: an RR interval ${(sorted.last / median).toStringAsFixed(1)}x the median, a missed beat?');
      if (sorted.first < 0.6 * median) print('   WARNING: an RR interval ${(sorted.first / median).toStringAsFixed(1)}x the median, an extra beat?');
    }
    ms.add(Measurement(c[0], c[1], (to - from) / sampleRate, beats.length, rrBpm,
        int.tryParse(c[2]), double.tryParse(c[3].replaceAll(',', '.')), lost, c[4]));
  }

  String f(double? x) => x == null ? '' : x.toStringAsFixed(1);
  print('file                                state      window  ECG  ECG bpm  RR bpm  manual  watch  lost');
  for (Measurement m in ms) {
    print('${m.file.padRight(35)} ${m.state.padRight(10)} ${f(m.windowSeconds).padLeft(6)} s '
        '${m.ecgCount.toString().padLeft(4)} ${f(m.ecgBpm).padLeft(8)} ${f(m.ecgRrBpm).padLeft(7)} '
        '${f(m.manualBpm).padLeft(7)} ${f(m.watchBpm).padLeft(6)} ${m.lostInWindow.toString().padLeft(5)}');
    if (m.lostInWindow > 0) print('   WARNING: ${m.lostInWindow} samples lost in the window, a beat may be missing');
  }
  print('');
  agreement('ECG - manual', ms, (m) => m.ecgBpm, (m) => m.manualBpm);
  agreement('ECG - watch ', ms, (m) => m.ecgBpm, (m) => m.watchBpm);
  agreement('manual - watch', ms, (m) => m.manualBpm, (m) => m.watchBpm);
  for (String state in ms.map((m) => m.state).toSet()) {
    List<Measurement> s = ms.where((m) => m.state == state).toList();
    print('-- $state:');
    agreement('  ECG - manual', s, (m) => m.ecgBpm, (m) => m.manualBpm);
    agreement('  ECG - watch ', s, (m) => m.ecgBpm, (m) => m.watchBpm);
  }

  StringBuffer csv = StringBuffer('file,state,window_s,ecg_count,ecg_bpm,ecg_rr_bpm,manual_count,manual_bpm,watch_bpm,lost_samples,note\n');
  for (Measurement m in ms) {
    csv.writeln('${m.file},${m.state},${f(m.windowSeconds)},${m.ecgCount},${m.ecgBpm.toStringAsFixed(2)},'
        '${m.ecgRrBpm?.toStringAsFixed(2) ?? ''},${m.manualCount ?? ''},${m.manualBpm?.toStringAsFixed(2) ?? ''},'
        '${m.watchBpm ?? ''},${m.lostInWindow},"${m.note.replaceAll('"', "'")}"');
  }
  File(args[1]).writeAsStringSync(csv.toString());
  print('saved: ${args[1]}');
}

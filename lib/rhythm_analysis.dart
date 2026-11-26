import 'dart:math';           // max
import 'beat_shape.dart';   // the correlation with the median beat
import 'qrs_width.dart';    // the median beat, the QRS width
import 'qt_interval.dart';  // the QT interval

// a simple rhythm check of a whole recording, from the heart beats (R waves) and their shape:
//  - the heart rate class: slow (bradycardia, < 60 bpm), normal, fast (tachycardia, > 100 bpm)
//  - premature beats (extra beats, extrasystoles): a beat that comes clearly too early
//    and is followed by a longer pause (the timing rule), OR a beat a bit early with a QRS of
//    another shape than the typical one (the shape rule, needs the signal)
//  - which of them are probably ventricular: another shape or a wide QRS
//  - ventricular beats in a row: a pair (2), a run (3 or more, a short ventricular tachycardia)
//  - pauses: no beat for 2 s or longer
// NOT a diagnosis: one lead; the app shows it as "worth showing to a doctor",
// the limits are the usual ones from the ECG textbooks, checked on MIT-BIH (tool/*_validation.dart)
enum HeartRateClass { slow, normal, fast }

class RhythmAnalysis {
  RhythmAnalysis._(this.rateClass, this.prematureBeats,
      {this.ventricular = const {}, this.runs = const [], this.pauses = const [], this.qrs, this.qt});

  final HeartRateClass rateClass;
  final List<int> prematureBeats;   // the sample numbers of the premature beats, in order
  final Set<int> ventricular;       // those of them that are probably ventricular
  final List<List<int>> runs;       // ventricular beats in a row, every list has 2 or more beats
  final List<(int, int)> pauses;    // (the beat before, the beat after) of every pause
  final QrsSummary? qrs;            // the median beat and the typical QRS, null = no signal given
  final QtSummary? qt;              // the long median beat and the QT, null = no measureSignal given

  int get pairs => runs.where((r) => r.length == 2).length;
  int get longRuns => runs.where((r) => r.length >= 3).length;

  // the usual adult resting limits
  static const int slowBelowBpm = 60;
  static const int fastAboveBpm = 100;

  // the timing rule: the interval BEFORE the beat is shorter than 80 % of the usual interval
  // (the median of the 8 intervals before it, a median so one earlier extra beat does not move it)
  static const double prematureRatio = 0.80;
  // and the interval AFTER it is at least 90 % of the usual one (the pause after an extra beat:
  // the heart "waits" for the next normal beat). This rule rejects a false detection
  // in the middle of a normal interval (e.g. a tall T wave or a movement): it splits
  // the interval into two short ones, and the second one is short too
  static const double pauseRatio = 0.90;
  static const int referenceIntervals = 8;

  // the shape rule: the correlation with the median beat under 0.7 and the interval before
  // the beat shorter than 95 % of the usual one (a ventricular beat that is only a bit early,
  // without the pause, or in a pair; "not late" leaves out the escape beats after a pause)
  // chosen on MIT-BIH (tool/shape_validation.dart): +P stays >= 90 %
  static const double shapeCorrelation = 0.70;
  static const double shapeEarliness = 0.95;

  // a pause: no beat for at least 2 s (as in Holter reports)
  static const double pauseSeconds = 2.0;
  // ... but if somewhere inside it the signal looks like the typical beat (correlation >= 0.9,
  // at least 30 % of its height), the detector missed a beat there: no pause
  // (on MIT-BIH most false pauses were such missed beats, the real ones never had one)
  static const double missedBeatCorrelation = 0.90;
  static const double missedBeatHeight = 0.30;

  // no beat is judged as premature this close to an artifact either: at its edges the movement
  // already disturbs the signal a little, a "beat" found there is often the disturbance itself
  // (30 min recording 2026-11-25: 3 of 4 false ventricular beats right next to an artifact)
  static const double artifactMarginSeconds = 1.0;

  // true = the sample is inside an artifact or within `margin` seconds of one
  // (checked every 100 ms: an artifact is at least 0.75 s long, see ArtifactDetector)
  static bool Function(int sample) nearDisturbed(bool Function(int sample) disturbed, int sampleRateHz,
      {double margin = artifactMarginSeconds}) {
    int reach = (margin * sampleRateHz).round(), step = max(1, (0.1 * sampleRateHz).round());
    return (int sample) {
      for (int d = -reach; d <= reach; d += step) {
        if (disturbed(sample + d)) return true;
      }
      return disturbed(sample + reach);
    };
  }

  // the same result without the beats for which `leaveOut` is true
  // (inside an atrial fibrillation episode "premature" has no meaning, every beat is irregular)
  // the pauses and the QRS stay
  RhythmAnalysis without(bool Function(int sample) leaveOut) => RhythmAnalysis._(
        rateClass,
        [for (int b in prematureBeats) if (!leaveOut(b)) b],
        ventricular: {for (int b in ventricular) if (!leaveOut(b)) b},
        runs: [for (List<int> r in runs) if (!r.any(leaveOut)) r],
        pauses: pauses,
        qrs: qrs,
        qt: qt,
      );

  static HeartRateClass classify(int averageBpm) {
    if (averageBpm < slowBelowBpm) return HeartRateClass.slow;
    if (averageBpm > fastAboveBpm) return HeartRateClass.fast;
    return HeartRateClass.normal;
  }

  // averageBpm: from RrStats (only the normal intervals, so the extra beats do not change it)
  // disturbed: true for a sample inside an artifact (cough, movement), there no beat is judged
  // (a plain function and not the Artifact list, so this file needs no Flutter and the
  //  validation tool can run it with plain dart)
  // signal: the filtered recording, for the shape rule and the QRS; null = only the timing rule
  // gaps: the lost BLE packets (first missing sample, next saved sample), a pause over a gap is not real
  static RhythmAnalysis analyze(List<int> beats, int sampleRateHz, int averageBpm,
      {bool Function(int sample) disturbed = _never, List<double>? signal, List<(int, int)> gaps = const [],
      List<double>? measureSignal, double artifactMargin = artifactMarginSeconds}) {
    // the premature beats: none in or next to an artifact; the pauses and the QRS: only inside
    bool Function(int sample) near = artifactMargin <= 0
        ? disturbed
        : nearDisturbed(disturbed, sampleRateHz, margin: artifactMargin);
    List<int> timing = findPremature(beats, sampleRateHz, disturbed: near);
    if (signal == null) {
      return RhythmAnalysis._(classify(averageBpm), timing,
          pauses: findPauses(beats, sampleRateHz, disturbed: disturbed, gaps: gaps));
    }

    // the median beat from the regular beats (the premature ones by timing left out)
    QrsSummary qrs = QrsSummary.analyze(signal, beats, sampleRateHz, premature: timing, disturbed: disturbed);
    List<double>? template = qrs.medianBeat;
    Set<int> timingSet = timing.toSet();
    Set<int> premature = {...timing};
    Set<int> ventricular = {};
    for (int k = 1; k < beats.length; k++) {
      int b = beats[k];
      if (near(b)) continue;
      double? correlation = template == null
          ? null
          : BeatShape.correlation(signal, b, template, qrs.r, sampleRateHz);
      bool otherShape = correlation != null && correlation < shapeCorrelation;
      if (otherShape && !timingSet.contains(b)) {
        int? reference = _reference(beats, k, sampleRateHz);
        if (reference != null && beats[k] - beats[k - 1] < shapeEarliness * reference) premature.add(b);
      }
      if (premature.contains(b) &&
          (otherShape || (QrsWidth.widthMs(signal, b, sampleRateHz) ?? 0) >= QrsWidth.wideMs)) {
        ventricular.add(b);
      }
    }
    List<(int, int)> pauses = findPauses(beats, sampleRateHz, disturbed: disturbed, gaps: gaps,
        signal: signal, template: template, templateR: qrs.r);
    List<int> sorted = premature.toList()..sort();
    // the QT: on the zero phase signal (measureSignal), from the same regular beats as the median beat
    QtSummary? qt;
    if (measureSignal != null) {
      List<int> regular = QrsWidth.regularBeats(beats, skip: timing.toSet(), disturbed: disturbed);
      List<int> intervals = [for (int k = 1; k < beats.length; k++) beats[k] - beats[k - 1]]..sort();
      if (intervals.isNotEmpty) {
        double rrMs = intervals[intervals.length ~/ 2] * 1000 / sampleRateHz;
        qt = QtSummary.analyze(signal, measureSignal, regular, rrMs, sampleRateHz);
      }
    }
    return RhythmAnalysis._(classify(averageBpm), sorted,
        ventricular: ventricular, runs: _runs(beats, ventricular), pauses: pauses, qrs: qrs, qt: qt);
  }

  // the usual interval before beat k: the median of the 8 believable intervals before beat k - 1,
  // null = not enough of them (the start of the recording, many gaps)
  // believable: 0.3-2.0 s like RrStats, a longer one is a missed beat or a lost packet
  static int? _reference(List<int> beats, int k, int sampleRateHz) {
    if (k < referenceIntervals + 1) return null;
    int minRr = (0.3 * sampleRateHz).round();
    int maxRr = (2.0 * sampleRateHz).round();
    List<int> usual = [
      for (int j = k - referenceIntervals; j < k; j++)
        if (beats[j] - beats[j - 1] >= minRr && beats[j] - beats[j - 1] <= maxRr) beats[j] - beats[j - 1],
    ];
    if (usual.length < referenceIntervals ~/ 2) return null;
    usual.sort();
    return usual[usual.length ~/ 2];
  }

  // the premature beats by the timing rule (their sample numbers), see prematureRatio and pauseRatio
  static List<int> findPremature(List<int> beats, int sampleRateHz,
      {bool Function(int sample) disturbed = _never,
      double prematureRatio = prematureRatio,
      double pauseRatio = pauseRatio}) {
    int maxRr = (2.0 * sampleRateHz).round();
    List<int> found = [];
    // beat k: the interval before it ends at k, the one after it starts at k
    for (int k = referenceIntervals + 1; k + 1 < beats.length; k++) {
      int before = beats[k] - beats[k - 1];
      int after = beats[k + 1] - beats[k];
      int? reference = _reference(beats, k, sampleRateHz);
      if (reference == null) continue;   // too many gaps around, no reference
      if (after > maxRr) continue;   // a gap after it, the pause can not be checked
      if (disturbed(beats[k - 1]) || disturbed(beats[k]) || disturbed(beats[k + 1])) continue;
      // the beat before it must have come on time: after a false detection in the middle of
      // an interval (300 + 500 ms) the next, real beat would look early too
      int previous = beats[k - 1] - beats[k - 2];
      if (previous < prematureRatio * reference) continue;
      if (before < prematureRatio * reference && after >= pauseRatio * reference) {
        found.add(beats[k]);
      }
    }
    return found;
  }

  // the ventricular beats that come one right after the other (neighbours in the beat list),
  // groups of 2 or more
  static List<List<int>> _runs(List<int> beats, Set<int> ventricular) {
    List<List<int>> runs = [];
    List<int> current = [];
    for (int b in beats) {
      if (ventricular.contains(b)) {
        current.add(b);
      } else {
        if (current.length >= 2) runs.add(current);
        current = [];
      }
    }
    if (current.length >= 2) runs.add(current);
    return runs;
  }

  // the pauses: two neighbour beats at least 2 s apart; not over a lost packet (the beats may be
  // in the missing part), not over an artifact (a movement can hide a beat from the detector),
  // and with the signal and the median beat: no missed beat inside (see missedBeatCorrelation)
  static List<(int, int)> findPauses(List<int> beats, int sampleRateHz,
      {bool Function(int sample) disturbed = _never, List<(int, int)> gaps = const [],
      List<double>? signal, List<double>? template, int templateR = 0}) {
    int limit = (pauseSeconds * sampleRateHz).round();
    int step = sampleRateHz ~/ 10;   // the artifacts are checked every 0.1 s
    List<(int, int)> found = [];
    for (int k = 1; k < beats.length; k++) {
      int a = beats[k - 1], b = beats[k];
      if (b - a < limit) continue;
      if (gaps.any((g) => g.$1 < b && g.$2 > a)) continue;
      bool clean = true;
      for (int s = a; s <= b && clean; s += step) {
        if (disturbed(s)) clean = false;
      }
      if (!clean || disturbed(b)) continue;
      if (signal != null && template != null && _missedBeat(signal, a, b, template, templateR, sampleRateHz)) continue;
      found.add((a, b));
    }
    return found;
  }

  // a place between the beats a and b (200 ms away from both) that looks like the typical beat
  // checked every 40 ms: the correlation itself tries shifts of +-20 ms
  static bool _missedBeat(List<double> x, int a, int b, List<double> template, int templateR, int sampleRateHz) {
    int margin = (0.2 * sampleRateHz).round();
    int step = (0.04 * sampleRateHz).round();
    for (int s = a + margin; s < b - margin; s += step) {
      double? c = BeatShape.correlation(x, s, template, templateR, sampleRateHz);
      if (c == null || c < missedBeatCorrelation) continue;
      double? h = BeatShape.heightRatio(x, s, template, templateR, sampleRateHz);
      if (h != null && h >= missedBeatHeight) return true;
    }
    return false;
  }

  static bool _never(int sample) => false;
}

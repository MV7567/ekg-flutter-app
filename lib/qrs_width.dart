import 'dart:math';   // max

// the width (duration) of the QRS complex, from the filtered EKG and the found R waves
//
// how one QRS is measured: the QRS is the steepest part of the EKG, the PR segment before it
// and the ST segment after it are almost flat, the P and T waves are slow
//   1. the slope |x[i+1] - x[i-1]| / 2 around the R wave
//   2. the steepest slope of this QRS = 100 %
//   3. the start: going back from the R wave, the first place where the slope stays under
//      quietRatio (of the steepest) for quietMs; the end: the same going forward
// a single "quiet" sample is not enough: at the top of the R wave and at the bottom of Q or S
// the slope is ~0 for a moment too, the flat segments last much longer
//
// the typical QRS of a recording is measured on the median beat: the normal beats laid on top
// of each other (aligned at R) and the median of every sample, the noise of single beats
// cancels out, one odd beat does not change it
// normal QRS in adults: 80-110 ms (lead II); >= 120 ms = wide (a bundle branch block,
// or a beat that started in the ventricles)
class QrsWidth {
  static const double quietRatio = 0.08;
  static const double quietMs = 16;          // 4 samples at 250 Hz
  static const double maxBeforeRMs = 120;    // the QRS start is searched at most this far before R
  static const double maxAfterRMs = 160;     // and the end at most this far after R
  static const double wideMs = 120;          // the usual limit of a wide QRS

  // (start, end) sample numbers of the QRS around the R wave at r, null = the signal is too
  // short there or no flat part was found (noise, a moving electrode)
  static (int, int)? measure(List<double> x, int r, int sampleRateHz,
      {double quietRatio = quietRatio, double quietMs = quietMs}) {
    int before = (maxBeforeRMs / 1000 * sampleRateHz).round();
    int after = (maxAfterRMs / 1000 * sampleRateHz).round();
    int quiet = max(2, (quietMs / 1000 * sampleRateHz).round());
    // + quiet: room to check that the flat part goes on behind the search limit
    int from = r - before - quiet, to = r + after + quiet;
    if (from < 1 || to >= x.length - 1) return null;

    double slope(int i) => (x[i + 1] - x[i - 1]).abs() / 2;
    double steepest = 0;
    for (int i = r - before ~/ 2; i <= r + after ~/ 2; i++) {
      steepest = max(steepest, slope(i));
    }
    if (steepest == 0) return null;
    double limit = quietRatio * steepest;

    bool flatFrom(int i, int direction) {
      for (int k = 0; k < quiet; k++) {
        if (slope(i + direction * k) >= limit) return false;
      }
      return true;
    }

    int? start, end;
    for (int i = r - 1; i >= r - before; i--) {
      if (flatFrom(i, -1)) {
        start = i;
        break;
      }
    }
    for (int i = r + 1; i <= r + after; i++) {
      if (flatFrom(i, 1)) {
        end = i;
        break;
      }
    }
    if (start == null || end == null) return null;
    return (start, end);
  }

  // the width in ms of one measured QRS
  static double? widthMs(List<double> x, int r, int sampleRateHz,
      {double quietRatio = quietRatio, double quietMs = quietMs}) {
    (int, int)? qrs = measure(x, r, sampleRateHz, quietRatio: quietRatio, quietMs: quietMs);
    return qrs == null ? null : (qrs.$2 - qrs.$1) * 1000 / sampleRateHz;
  }

  // the median beat: for every sample around R the median of all the given beats,
  // returns (the samples, the position of R in them), null = fewer than minBeats usable beats
  static const int minBeats = 5;
  static (List<double>, int)? medianBeat(List<double> x, List<int> beats, int sampleRateHz) {
    // a bit more than the measure() limits, it needs the flat part behind them
    // (40 ms: room for the longest flat part that is checked)
    int before = ((maxBeforeRMs + 40) / 1000 * sampleRateHz).round() + 2;
    int after = ((maxAfterRMs + 40) / 1000 * sampleRateHz).round() + 2;
    List<int> usable = [for (int r in beats) if (r - before >= 0 && r + after < x.length) r];
    if (usable.length < minBeats) return null;
    List<double> median = List.filled(before + after + 1, 0);
    List<double> column = List.filled(usable.length, 0);
    for (int i = -before; i <= after; i++) {
      for (int k = 0; k < usable.length; k++) {
        column[k] = x[usable[k] + i];
      }
      column.sort();
      int m = column.length ~/ 2;
      median[i + before] = column.length.isOdd ? column[m] : (column[m - 1] + column[m]) / 2;
    }
    return (median, before);
  }

  // the beats for the median beat: both intervals around the beat within 20 % of the usual
  // (the median of the recording), so no premature beat, no beat after a missed one, no false
  // detection; skip: e.g. the premature beats, disturbed: inside an artifact
  static List<int> regularBeats(List<int> beats, {Set<int> skip = const {},
      bool Function(int sample) disturbed = _never}) {
    if (beats.length < 3) return [];
    List<int> intervals = [for (int k = 1; k < beats.length; k++) beats[k] - beats[k - 1]]..sort();
    int usual = intervals[intervals.length ~/ 2];
    bool near(int rr) => (rr - usual).abs() <= 0.2 * usual;
    return [
      for (int k = 1; k + 1 < beats.length; k++)
        if (near(beats[k] - beats[k - 1]) && near(beats[k + 1] - beats[k]) &&
            !skip.contains(beats[k]) && !disturbed(beats[k]))
          beats[k],
    ];
  }

  static bool _never(int sample) => false;

  // the typical QRS width of a recording in ms: measured on the median of the given beats
  // (the caller gives only the normal ones: no premature beats, none inside an artifact)
  static double? typicalMs(List<double> x, List<int> normalBeats, int sampleRateHz,
      {double quietRatio = quietRatio, double quietMs = quietMs}) {
    (List<double>, int)? beat = medianBeat(x, normalBeats, sampleRateHz);
    if (beat == null) return null;
    return widthMs(beat.$1, beat.$2, sampleRateHz, quietRatio: quietRatio, quietMs: quietMs);
  }
}

// everything about the QRS of one recording, for the statistics card and the PDF report
class QrsSummary {
  QrsSummary._(this.medianBeat, this.r, this.qrs, this.beatCount, this.widePremature);

  final List<double>? medianBeat;   // the median beat (mV), null = fewer than 5 regular beats
  final int r;                      // the position of R in medianBeat
  final (int, int)? qrs;            // start and end of the QRS in medianBeat, null = not measured
  final int beatCount;              // how many beats are in the median beat
  final Set<int> widePremature;     // the premature beats (sample numbers) with a wide QRS

  double? typicalMs(int sampleRateHz) => qrs == null ? null : (qrs!.$2 - qrs!.$1) * 1000 / sampleRateHz;

  // x: the filtered recording, premature: from RhythmAnalysis (left out of the median beat,
  // each of them measured on its own: wide = probably from the ventricles)
  static QrsSummary analyze(List<double> x, List<int> beats, int sampleRateHz,
      {List<int> premature = const [], bool Function(int sample) disturbed = QrsWidth._never}) {
    List<int> regular = QrsWidth.regularBeats(beats, skip: premature.toSet(), disturbed: disturbed);
    (List<double>, int)? median = QrsWidth.medianBeat(x, regular, sampleRateHz);
    (int, int)? qrs = median == null ? null : QrsWidth.measure(median.$1, median.$2, sampleRateHz);
    Set<int> wide = {
      for (int b in premature)
        if ((QrsWidth.widthMs(x, b, sampleRateHz) ?? 0) >= QrsWidth.wideMs) b,
    };
    return QrsSummary._(median?.$1, median?.$2 ?? 0, qrs, median == null ? 0 : regular.length, wide);
  }
}

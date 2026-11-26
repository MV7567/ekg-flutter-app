import 'dart:math';           // max
import 'dart:typed_data';     // Float32List
import 'screens/recordings_screen.dart';   // formatDuration

// one disturbed part of a recording (cough, moving, a loose electrode), in sample numbers
class Artifact {
  const Artifact(this.start, this.end);
  final int start;   // the first disturbed sample
  final int end;     // after the last one (end - start = length)

  bool contains(int sample) => sample >= start && sample < end;

  @override
  bool operator ==(Object other) => other is Artifact && other.start == start && other.end == end;
  @override
  int get hashCode => Object.hash(start, end);
  @override
  String toString() => 'Artifact($start, $end)';
}

// "2:03 (2 s)": where a disturbance starts and how long it is, for the chips and the PDF
String artifactLabel(Artifact a, int sampleRateHz) {
  String start = RecordingsScreen.formatDuration(Duration(milliseconds: a.start * 1000 ~/ sampleRateHz));
  int seconds = max(1, ((a.end - a.start) / sampleRateHz).round());
  return '$start ($seconds s)';
}

// finds the disturbed parts of a whole (filtered) recording, done when the recording is opened,
// so it also works for old files and the CSV format doesn't change
// the idea: between the heart beats a clean EKG is calm (only the small P and T waves),
// a cough or a movement makes big swings or fast wiggling exactly there
class ArtifactDetector {
  static const double windowSeconds = 0.25;   // the signal is checked in short pieces
  // around every found beat the QRS itself is not checked (it is big and steep on purpose)
  static const double qrsBeforeSeconds = 0.08;
  static const double qrsAfterSeconds = 0.12;
  // a swing between the beats bigger than this part of the usual R wave = not the heart
  // (a T wave is usually under half of the R wave)
  static const double swingOfR = 0.8;
  static const double minSwingMillivolts = 0.1;   // never call less than this a disturbance
  // fast wiggling: the median step between samples, the same idea as SignalQualityMonitor
  static const double maxTypicalSlope = 0.03;
  static const double wiggleOfR = 0.03;   // ... or 3 % of the usual R wave, if that is more
  // a found "beat" that the heart can not make is the disturbance itself, its QRS does not hide it
  static const double impossibleRrSeconds = 0.3;
  static const double impossibleHeightOfR = 3;
  // pieces closer than this are one disturbance, and every disturbance gets this margin
  static const double joinSeconds = 0.5;
  static const double marginSeconds = 0.25;
  // the beginning is not checked: the signal settles and the beat detector is still learning
  // (no beats found yet = the QRS would count as a swing), see also PdfReport.skipSeconds
  static const double skipSeconds = 3;

  static List<Artifact> find(Float32List mv, List<int> beats, int sampleRateHz) {
    int n = mv.length;
    if (n < sampleRateHz) return [];

    // the usual R wave: the median height at the found beats
    List<double> heights = [for (int b in beats) if (b >= 0 && b < n) mv[b].abs()]..sort();
    double typicalR = heights.length >= 3 ? heights[heights.length ~/ 2] : _percentile(mv, 0.95);
    double swingLimit = max(minSwingMillivolts, swingOfR * typicalR);
    double wiggleLimit = max(maxTypicalSlope, wiggleOfR * typicalR);

    // true = this sample belongs to a QRS, not checked for swings
    // only the believable beats: a "beat" much too early or much too high is usually the
    // disturbance itself (found by the detector), its QRS must not hide it
    List<bool> qrs = List.filled(n, false);
    int before = (qrsBeforeSeconds * sampleRateHz).round();
    int after = (qrsAfterSeconds * sampleRateHz).round();
    for (int k = 0; k < beats.length; k++) {
      int b = beats[k];
      if (b < 0 || b >= n) continue;
      // (2026-11-25) only an IMPOSSIBLE beat: less than 0.3 s from its neighbour (200 bpm) or over
      // 3x the usual R wave. Before: earlier than 70 % of the usual interval or over 2x the R wave,
      // and that is exactly how a ventricular premature beat looks (early and tall): on MIT-BIH
      // 13 % of the time was "disturbed" and the app found only 21 % of the premature beats
      int minRr = (impossibleRrSeconds * sampleRateHz).round();
      bool early = (k > 0 && beats[k] - beats[k - 1] < minRr) ||
          (k + 1 < beats.length && beats[k + 1] - beats[k] < minRr);
      bool tooHigh = heights.length >= 3 && mv[b].abs() > impossibleHeightOfR * typicalR;
      if (early || tooHigh) continue;
      for (int i = max(0, b - before); i < min(n, b + after); i++) {
        qrs[i] = true;
      }
    }

    // every window: disturbed or not
    int window = (windowSeconds * sampleRateHz).round();
    List<Artifact> bad = [];
    int skip = (skipSeconds * sampleRateHz).round();
    for (int start = skip; start + window <= n; start += window) {
      double swing = 0;
      List<double> slopes = [];
      for (int i = start; i < start + window; i++) {
        if (!qrs[i]) swing = max(swing, mv[i].abs());
        // the wiggling also only between the beats, and relative to the R wave (2026-11-25): a QRS or
        // a T wave in the window, or simply a bigger EKG (MIT-BIH: R 1-3 mV, own: 0.3-0.9 mV), made
        // the median step bigger than 0.03 mV in clean windows
        if (i > 0 && !qrs[i]) slopes.add((mv[i] - mv[i - 1]).abs());
      }
      slopes.sort();
      bool wiggling = slopes.length >= window ~/ 4 && slopes[slopes.length ~/ 2] > wiggleLimit;
      if (swing > swingLimit || wiggling) bad.add(Artifact(start, start + window));
    }

    // the margin first, then join pieces that are close (or overlap after the margin)
    int join = (joinSeconds * sampleRateHz).round();
    int margin = (marginSeconds * sampleRateHz).round();
    List<Artifact> joined = [];
    for (Artifact piece in bad) {
      Artifact a = Artifact(max(skip, piece.start - margin), min(n, piece.end + margin));
      if (joined.isNotEmpty && a.start - joined.last.end <= join) {
        joined[joined.length - 1] = Artifact(joined.last.start, a.end);
      } else {
        joined.add(a);
      }
    }
    return joined;
  }

  static double _percentile(Float32List mv, double p) {
    List<double> sorted = [for (double x in mv) x.abs()]..sort();
    return sorted[(p * (sorted.length - 1)).round()];
  }
}

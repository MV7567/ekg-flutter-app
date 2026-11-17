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

    // true = this sample belongs to a QRS, not checked for swings
    // only the believable beats: a "beat" much too early or much too high is usually the
    // disturbance itself (found by the detector), its QRS must not hide it
    List<int> rr = [for (int i = 1; i < beats.length; i++) beats[i] - beats[i - 1]]..sort();
    int typicalRr = rr.isEmpty ? 0 : rr[rr.length ~/ 2];
    List<bool> qrs = List.filled(n, false);
    int before = (qrsBeforeSeconds * sampleRateHz).round();
    int after = (qrsAfterSeconds * sampleRateHz).round();
    for (int k = 0; k < beats.length; k++) {
      int b = beats[k];
      if (b < 0 || b >= n) continue;
      bool early = k > 0 && beats[k] - beats[k - 1] < 0.7 * typicalRr;
      bool tooHigh = heights.length >= 3 && mv[b].abs() > 2 * typicalR;
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
        if (i > 0) slopes.add((mv[i] - mv[i - 1]).abs());
      }
      slopes.sort();
      bool wiggling = slopes[slopes.length ~/ 2] > maxTypicalSlope;
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

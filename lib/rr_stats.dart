import 'dart:math';   // sqrt, min, max
import 'artifact_detector.dart';   // Artifact

// one point of the tachogram: when the interval ended and how long it was
class RrPoint {
  const RrPoint(this.seconds, this.rrMs);
  final double seconds;   // time of the second beat of the interval, from the start of the recording
  final double rrMs;      // the RR interval in milliseconds
}

// statistics of a whole recording from its heart beats (R waves):
//  - heart rate: min / average / max
//  - HRV (heart rate variability), the two most common time-domain measures:
//      SDNN  = standard deviation of the intervals: the total variability
//              (breathing, rest, everything), resting adults ~30-100 ms in a few minutes
//      RMSSD = root of the mean squared difference of NEIGHBOUR intervals: the fast changes
//              from beat to beat (the vagus nerve, breathing), resting adults ~20-80 ms
//  - the tachogram: every RR interval over time, shows breathing and the trend of the heart rate
//
// only "normal" intervals are used (NN = normal-to-normal): a missed beat (a double interval),
// an extra one (an artifact counted as a beat) or a lost packet would add a huge fake
// variability, one such error can double the SDNN, so they are left out and counted
class RrStats {
  RrStats._({
    required this.beatCount,
    required this.excludedIntervals,
    required this.minBpm,
    required this.averageBpm,
    required this.maxBpm,
    required this.sdnnMs,
    required this.rmssdMs,
    required this.tachogram,
  });

  final int beatCount;           // all detected beats
  final int excludedIntervals;   // intervals left out as not normal
  final int minBpm, averageBpm, maxBpm;
  final double sdnnMs;
  final double? rmssdMs;         // null = fewer than 2 pairs of neighbour normal intervals
  final List<RrPoint> tachogram; // only the normal intervals

  // the same limits as the heart rate detector: 0.3-2.0 s (200-30 bpm)
  static const double _minRrSeconds = 0.3;
  static const double _maxRrSeconds = 2.0;
  // an interval more than 30 % away from the median is not normal
  // (the same rule as HeartRateDetector.averageBpm, so both show the same average)
  static const double _maxDeviation = 0.3;
  static const int _minIntervals = 3;

  // null = fewer than 3 normal intervals, nothing to show
  // artifacts: an interval with a beat inside a disturbed part is not normal either
  // (a cough can make a "beat" or hide one, the interval would be wrong)
  static RrStats? fromBeats(List<int> beats, int sampleRateHz, {List<Artifact> artifacts = const []}) {
    if (beats.length < 2) return null;

    // 1. every interval, and which of them are normal
    List<int> intervals = [for (int k = 1; k < beats.length; k++) beats[k] - beats[k - 1]];
    bool disturbed(int sample) => artifacts.any((a) => a.contains(sample));
    // interval k is between beats k and k + 1
    List<bool> clean = [for (int k = 0; k < intervals.length; k++) !disturbed(beats[k]) && !disturbed(beats[k + 1])];
    List<int> believable = intervals
        .where((rr) => rr >= _minRrSeconds * sampleRateHz && rr <= _maxRrSeconds * sampleRateHz)
        .toList();
    if (believable.length < _minIntervals) return null;
    List<int> sorted = List.of(believable)..sort();
    int median = sorted[sorted.length ~/ 2];
    bool isNormal(int k) =>
        clean[k] &&
        intervals[k] >= _minRrSeconds * sampleRateHz &&
        intervals[k] <= _maxRrSeconds * sampleRateHz &&
        (intervals[k] - median).abs() <= _maxDeviation * median;

    // 2. the normal intervals in ms, with their time, and the beat-to-beat differences
    double msPerSample = 1000 / sampleRateHz;
    List<double> nn = [];
    List<RrPoint> points = [];
    List<double> differences = [];   // only between two NEIGHBOUR normal intervals
    for (int k = 0; k < intervals.length; k++) {
      if (!isNormal(k)) continue;
      double rrMs = intervals[k] * msPerSample;
      // the previous interval in the recording must be normal too, otherwise the
      // difference would jump over a gap (a missed beat) and be meaningless
      if (k > 0 && isNormal(k - 1)) {
        differences.add(rrMs - intervals[k - 1] * msPerSample);
      }
      nn.add(rrMs);
      points.add(RrPoint(beats[k + 1] / sampleRateHz, rrMs));
    }
    if (nn.length < _minIntervals) return null;

    // 3. heart rate: a short interval = a fast heart, 60 000 ms per minute
    double mean = nn.reduce((a, b) => a + b) / nn.length;
    int bpm(double rrMs) => (60000 / rrMs).round();

    // 4. SDNN: standard deviation (n - 1: a sample of the person's rhythm, not all of it)
    double sumSquares = 0;
    for (double rr in nn) {
      sumSquares += (rr - mean) * (rr - mean);
    }
    double sdnn = sqrt(sumSquares / (nn.length - 1));

    // 5. RMSSD: root of the mean squared beat-to-beat difference
    double? rmssd;
    if (differences.length >= 2) {
      double sum = 0;
      for (double d in differences) {
        sum += d * d;
      }
      rmssd = sqrt(sum / differences.length);
    }

    return RrStats._(
      beatCount: beats.length,
      excludedIntervals: intervals.length - nn.length,
      minBpm: bpm(nn.reduce(max)),    // the longest interval = the slowest heart
      averageBpm: bpm(mean),
      maxBpm: bpm(nn.reduce(min)),    // the shortest interval = the fastest heart
      sdnnMs: sdnn,
      rmssdMs: rmssd,
      tachogram: points,
    );
  }
}

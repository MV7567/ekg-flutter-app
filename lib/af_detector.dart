import 'dart:math';   // max

// a suspicion of atrial fibrillation (AF), only from the heart beats (R waves)
//
// in AF the atria do not beat, they quiver, the ventricles get impulses at random moments:
// the rhythm is "irregularly irregular", almost every RR interval differs clearly from the one
// before it. A normal (sinus) rhythm changes slowly (breathing), so the neighbour intervals are
// close; a premature beat makes a big jump too, but only now and then.
// so the measure is the MEDIAN of the differences of neighbour intervals, relative to the
// typical interval, in a window of 30 intervals: a few premature beats do not move the median,
// in AF it is high
//
// a window above the limit = irregular, the irregular windows joined together = an episode,
// shown only if it lasts at least 30 s (the usual clinical definition of an AF episode)
// NOT a diagnosis: atrial flutter often has a regular rhythm and is not found, frequent
// premature beats in a row (e.g. every 2nd) can look irregular too
class AfDetector {
  AfDetector._(this.episodes);

  final List<(int, int)> episodes;   // (start, end) sample numbers of the irregular parts >= 30 s

  static const int windowIntervals = 30;
  // median |difference| > 10 % of the typical interval; chosen on MIT-BIH (tool/af_validation.dart):
  // every AF record found, few false episodes in the records without frequent premature beats
  static const double irregularLimit = 0.10;
  static const double minEpisodeSeconds = 30;

  // the same believable limits as RrStats, a bit lower at the bottom: AF can be fast
  static const double _minRrSeconds = 0.25;
  static const double _maxRrSeconds = 2.0;

  bool get suspected => episodes.isNotEmpty;

  // the total length of the episodes in seconds
  double seconds(int sampleRateHz) => episodes.fold(0, (s, e) => s + (e.$2 - e.$1) / sampleRateHz);

  // disturbed: a sample inside an artifact, the intervals around it are not used
  static AfDetector analyze(List<int> beats, int sampleRateHz,
      {bool Function(int sample) disturbed = _never,
      double limit = irregularLimit,
      double minEpisodeSeconds = minEpisodeSeconds}) {
    List<(int, int)> windows = irregularWindows(beats, sampleRateHz, disturbed: disturbed, limit: limit);
    // join the overlapping / touching windows
    List<(int, int)> joined = [];
    for (var (start, end) in windows) {
      if (joined.isNotEmpty && start <= joined.last.$2) {
        joined[joined.length - 1] = (joined.last.$1, max(joined.last.$2, end));
      } else {
        joined.add((start, end));
      }
    }
    return AfDetector._([
      for (var e in joined) if ((e.$2 - e.$1) / sampleRateHz >= minEpisodeSeconds) e,
    ]);
  }

  // (first beat, last beat) of every window of 30 usable intervals that is irregular
  static List<(int, int)> irregularWindows(List<int> beats, int sampleRateHz,
      {bool Function(int sample) disturbed = _never, double limit = irregularLimit}) {
    List<(int, int)> found = [];
    for (int first = 0; first + windowIntervals < beats.length; first++) {
      double? value = irregularity(beats, first, sampleRateHz, disturbed: disturbed);
      if (value != null && value > limit) found.add((beats[first], beats[first + windowIntervals]));
    }
    return found;
  }

  // the measure for the window of 30 intervals starting at beat `first`:
  // median |RR[k] - RR[k - lag]| / median RR, the smallest of lag = 1, 2, 3
  // lag 1 = neighbour intervals; lag 2 and 3 because a REPEATING pattern is not AF:
  // in bigeminy (every 2nd beat premature: short, long, short, long...) the neighbours differ a lot,
  // but every 2nd interval is the same, in trigeminy every 3rd; in AF nothing repeats
  // only usable intervals (believable, not in an artifact)
  // null = fewer than 2/3 of the intervals usable (artifacts, lost packets): not judged
  static const int maxLag = 3;
  static double? irregularity(List<int> beats, int first, int sampleRateHz,
      {bool Function(int sample) disturbed = _never, int maxLag = maxLag}) {
    int minRr = (_minRrSeconds * sampleRateHz).round();
    int maxRr = (_maxRrSeconds * sampleRateHz).round();
    List<int?> rr = [
      for (int k = first; k < first + windowIntervals; k++)
        (beats[k + 1] - beats[k] >= minRr && beats[k + 1] - beats[k] <= maxRr &&
                !disturbed(beats[k]) && !disturbed(beats[k + 1]))
            ? beats[k + 1] - beats[k]
            : null,
    ];
    List<int> usable = [for (int? v in rr) ?v]..sort();
    if (usable.length < windowIntervals * 2 ~/ 3) return null;

    double? smallest;
    for (int lag = 1; lag <= maxLag; lag++) {
      List<int> differences = [
        for (int i = lag; i < rr.length; i++)
          if (rr[i] != null && rr[i - lag] != null) (rr[i]! - rr[i - lag]!).abs(),
      ]..sort();
      if (differences.length < (windowIntervals - lag) * 2 ~/ 3) continue;
      double m = _median(differences);
      if (smallest == null || m < smallest) smallest = m;
    }
    return smallest == null ? null : smallest / _median(usable);
  }

  static double _median(List<int> sorted) {
    int m = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[m].toDouble() : (sorted[m - 1] + sorted[m]) / 2;
  }

  static bool _never(int sample) => false;

  // is this sample inside one of the episodes (e.g. a premature beat there means nothing)
  bool contains(int sample) => episodes.any((e) => sample >= e.$1 && sample <= e.$2);
}

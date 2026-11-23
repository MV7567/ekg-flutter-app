// a simple rhythm check of a whole recording, only from the heart beats (R waves):
//  - the heart rate class: slow (bradycardia, < 60 bpm), normal, fast (tachycardia, > 100 bpm)
//  - premature beats (extra beats, extrasystoles): a beat that comes clearly too early
//    and is followed by a longer pause
// NOT a diagnosis: one lead, no beat shape is checked yet; the app shows it as
// "worth showing to a doctor", the limits are the usual ones from the ECG textbooks
enum HeartRateClass { slow, normal, fast }

class RhythmAnalysis {
  RhythmAnalysis._(this.rateClass, this.prematureBeats);

  final HeartRateClass rateClass;
  final List<int> prematureBeats;   // the sample numbers of the premature beats

  // the usual adult resting limits
  static const int slowBelowBpm = 60;
  static const int fastAboveBpm = 100;

  // a premature beat: the interval BEFORE it is shorter than 80 % of the usual interval
  // (the median of the 8 intervals before it, a median so one earlier extra beat does not move it)
  static const double prematureRatio = 0.80;
  // and the interval AFTER it is at least 90 % of the usual one (the pause after an extra beat:
  // the heart "waits" for the next normal beat). This rule rejects a false detection
  // in the middle of a normal interval (e.g. a tall T wave or a movement): it splits
  // the interval into two short ones, and the second one is short too
  static const double pauseRatio = 0.90;
  static const int referenceIntervals = 8;

  static HeartRateClass classify(int averageBpm) {
    if (averageBpm < slowBelowBpm) return HeartRateClass.slow;
    if (averageBpm > fastAboveBpm) return HeartRateClass.fast;
    return HeartRateClass.normal;
  }

  // averageBpm: from RrStats (only the normal intervals, so the extra beats do not change it)
  // disturbed: true for a sample inside an artifact (cough, movement), there no beat is judged
  // (a plain function and not the Artifact list, so this file needs no Flutter and the
  //  validation tool can run it with plain dart)
  static RhythmAnalysis analyze(List<int> beats, int sampleRateHz, int averageBpm,
      {bool Function(int sample) disturbed = _never}) {
    return RhythmAnalysis._(classify(averageBpm), findPremature(beats, sampleRateHz, disturbed: disturbed));
  }

  // the premature beats (their sample numbers), see prematureRatio and pauseRatio
  static List<int> findPremature(List<int> beats, int sampleRateHz,
      {bool Function(int sample) disturbed = _never,
      double prematureRatio = prematureRatio,
      double pauseRatio = pauseRatio}) {
    // the same believable limits as RrStats: 0.3-2.0 s, a longer one is a missed beat
    // or a lost packet and must not become "the usual interval"
    int minRr = (0.3 * sampleRateHz).round();
    int maxRr = (2.0 * sampleRateHz).round();

    List<int> found = [];
    // beat k: the interval before it ends at k, the one after it starts at k
    // the reference needs 8 intervals before the beat k - 1
    for (int k = referenceIntervals + 1; k + 1 < beats.length; k++) {
      int before = beats[k] - beats[k - 1];
      int after = beats[k + 1] - beats[k];
      List<int> usual = [
        for (int j = k - referenceIntervals; j < k; j++)
          if (beats[j] - beats[j - 1] >= minRr && beats[j] - beats[j - 1] <= maxRr) beats[j] - beats[j - 1],
      ];
      if (usual.length < referenceIntervals ~/ 2) continue;   // too many gaps around, no reference
      usual.sort();
      int reference = usual[usual.length ~/ 2];
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

  static bool _never(int sample) => false;
}

import 'dart:math';         // max
import 'dart:typed_data';   // Float64List
import 'filters/biquad_filter.dart';   // the 5-15 Hz band-pass

// finds the heart beats (R waves) in the EKG and gives the heart rate in beats per minute
// a simplified Pan-Tompkins algorithm (1985), the classic QRS detector:
//   0. band-pass    - 5-15 Hz, where most of the QRS energy is: removes what is left of the
//                     50 Hz hum, the slow T wave and the wander (the display filter keeps 0.5-40 Hz)
//   1. derivative   - the QRS is the steepest part of the EKG, P and T waves are slow
//   2. square       - only positive values, big slopes become much bigger than small ones,
//                     and spikes pointing down count the same as spikes pointing up
//   3. moving sum   - over 150 ms (the width of a QRS), one smooth hump per beat
//   4. threshold    - a hump higher than the threshold is a beat, the threshold follows
//                     the height of the last beats and of the noise (adapts to the person)
//   5. refractory   - no second beat within 250 ms (the heart can't, max 240 bpm)
//   6. no beat for a long time -> the threshold goes down (the last beats were maybe an artifact)
// input: the FILTERED signal in mV (the display filter: no DC, no 50 Hz, no wander)
class HeartRateDetector {
  HeartRateDetector(this.sampleRateHz)
      : _window = Float64List((0.150 * sampleRateHz).round()),
        _history = Float64List((0.5 * sampleRateHz).round()),
        _refractorySamples = (0.250 * sampleRateHz).round(),
        _settleSamples = (0.5 * sampleRateHz).round(),
        _learningSamples = 2 * sampleRateHz,
        _bandHigh = BiquadFilter.highPass(frequencyHz: 5, sampleRateHz: sampleRateHz.toDouble()),
        _bandLow = BiquadFilter.lowPass(frequencyHz: 15, sampleRateHz: sampleRateHz.toDouble());

  final int sampleRateHz;

  final Float64List _window;        // last 150 ms of squared slopes, ring buffer
  int _windowPos = 0;
  double _windowSum = 0;

  // the 5-15 Hz band-pass, a high-pass and a low-pass one after another
  final BiquadFilter _bandHigh, _bandLow;

  // the last 0.5 s of the input, to find the top of the R wave: the band-pass delays the hump
  // a little, so the R wave can be just BEFORE the hump starts
  final Float64List _history;

  final int _refractorySamples;     // 250 ms
  final int _settleSamples;         // the first 0.5 s: the filters jump at the start, nothing is learned
  final int _learningSamples;       // the next 2 s only measure how high the beats are
  int _samplesSeen = 0;
  double _learningMax = 0;

  double _x1 = 0, _x2 = 0;          // the last two band-passed samples, for the derivative
  double _m1 = 0, _m2 = 0;          // the last two input samples, for the steepness of the QRS
  double _i1 = 0, _i2 = 0;          // the last two values of the moving sum, to find its peaks

  double _signalLevel = 0;          // typical height of a beat hump (SPKI in Pan-Tompkins)
  double _noiseLevel = 0;           // typical height of the other humps (NPKI)

  // the hump of the moving sum that is above the threshold right now (a QRS candidate)
  bool _inHump = false;
  int _humpStart = 0;
  double _humpMax = 0;              // highest value of the moving sum in this hump
  double _humpRAmplitude = 0;       // highest |EKG| in this hump, the R wave (found when the hump ends)
  int _humpRIndex = 0;              // and where it was = the time of the beat
  double _humpMaxSlope = 0;         // steepest |slope| in this hump, in mV per derivative step (8 ms)

  int? _lastBeat;                   // sample number of the last beat (its R wave)
  int _lastLevelChange = 0;         // last beat, or the last time the threshold was lowered
  int _lastSample = 0;
  final List<int> _rrIntervals = [];   // last RR intervals in samples (time between beats)

  static const int _rrToKeep = 5;          // bpm = median of the last 5 intervals
  static const int _rrNeeded = 3;          // bpm shown only after 3 intervals (4 beats), not after one lucky one
  // a real QRS is at least ~0.07 mV high (wrists, lead I: often only 0.2-0.3 mV,
  // a badly stuck electrode gave beats of only 0.07-0.15 mV that were still clearly beats)
  static const double _minRMillivolts = 0.07;
  // a QRS is steep: ~1 mV in 40 ms = 25 mV/s, a slow wave (breathing, moving) is much slower,
  // under 4 mV/s it is no beat even if it is high and regular (a small 0.2 mV R wave still has ~5 mV/s)
  static const double _minSlopeMillivoltsPerSecond = 4;
  static const double _minRrSeconds = 0.3; // 200 bpm
  static const double _maxRrSeconds = 2.0; // 30 bpm, a longer gap = lost signal, not a beat
  static const double _timeoutSeconds = 3; // no beat for 3 s -> bpm unknown
  // no beat for 1.5 s (or 1.5 x the usual interval at a slow heart): the threshold is halved
  static const double _searchBackSeconds = 1.5;

  // one filtered sample, sampleIndex counts the lost packets too (the real time)
  // returns true when this sample finished a beat
  bool addSample(int sampleIndex, double millivolts) {
    _lastSample = sampleIndex;
    _history[sampleIndex % _history.length] = millivolts;

    // steepness of the input itself, a QRS is much steeper than a slow wave
    double inputSlope = millivolts - _m2;
    _m2 = _m1;
    _m1 = millivolts;

    // 0. band-pass 5-15 Hz
    double band = _bandLow.process(_bandHigh.process(millivolts));

    // 1. derivative over 2 samples (8 ms), 2. square
    double slope = band - _x2;
    _x2 = _x1;
    _x1 = band;
    double squared = slope * slope;

    // 3. moving sum over 150 ms: add the newest, remove the oldest
    _windowSum += squared - _window[_windowPos];
    _window[_windowPos] = squared;
    _windowPos = (_windowPos + 1) % _window.length;
    double integrated = _windowSum < 0 ? 0 : _windowSum;   // rounding errors could go a bit below 0

    // a peak of the moving sum: the previous value is higher than its neighbours
    bool isPeak = _i1 > _i2 && _i1 >= integrated;
    double peak = _i1;
    _i2 = _i1;
    _i1 = integrated;

    _samplesSeen++;
    if (_samplesSeen <= _settleSamples) return false;   // the filters are still settling
    if (_samplesSeen <= _settleSamples + _learningSamples) {
      // learning: in 2 s there are at least 1-2 beats, the highest hump is a beat
      if (integrated > _learningMax) _learningMax = integrated;
      if (_samplesSeen == _settleSamples + _learningSamples) {
        _signalLevel = 0.5 * _learningMax;
        _noiseLevel = 0.05 * _learningMax;
        _lastLevelChange = sampleIndex;
      }
      return false;
    }

    // 4. threshold between the noise and the beats, a quarter of the way up
    double threshold = _noiseLevel + 0.25 * (_signalLevel - _noiseLevel);

    // one QRS makes a hump with a few small bumps on it (Q, R, S),
    // so the whole hump above the threshold is one candidate,
    // and the beat time is where the EKG itself is the furthest from 0 = the top of the R wave
    if (_inHump) {
      if (integrated > _humpMax) _humpMax = integrated;
      if (inputSlope.abs() > _humpMaxSlope) _humpMaxSlope = inputSlope.abs();
      // the hump ends when the sum falls under the threshold (or after 300 ms, wider is no QRS)
      if (integrated < threshold) {
        _inHump = false;
        _findR(sampleIndex);
        return _endOfHump();
      }
      if (sampleIndex - _humpStart > 0.3 * sampleRateHz) {
        // still above the threshold after 300 ms: too wide for a QRS (a slow wave, moving),
        // it only teaches the noise level
        _inHump = false;
        _learnNoise(_humpMax);
        return false;
      }
      return false;
    }

    if (integrated > threshold &&
        (_lastBeat == null || sampleIndex - _lastBeat! > _refractorySamples)) {
      // a new hump starts
      _inHump = true;
      _humpStart = sampleIndex;
      _humpMax = integrated;
      // the steepest input slope from a bit before the hump (the band-pass delays it)
      _humpMaxSlope = inputSlope.abs();
      for (int k = 1; k < _lookBackSamples; k++) {
        double s = (_history[(sampleIndex - k) % _history.length] -
                _history[(sampleIndex - k - 2) % _history.length])
            .abs();
        if (s > _humpMaxSlope) _humpMaxSlope = s;
      }
      return false;
    }

    // 6. no beat for a long time: maybe the level is too high (a big artifact counted as a beat,
    //    or the electrodes moved and the beats got smaller) -> halve it, it may halve again later
    if (sampleIndex - _lastLevelChange > _searchBackSamples) {
      _signalLevel = max(0.5 * _signalLevel, 2 * _noiseLevel);
      _lastLevelChange = sampleIndex;
    }

    // a smaller hump that never reached the threshold (T wave, noise): it teaches the noise level
    if (isPeak && peak <= threshold) _noiseLevel = 0.125 * peak + 0.875 * _noiseLevel;
    return false;
  }

  // 100 ms back, the band-pass + the moving sum start the hump a little after the QRS starts
  int get _lookBackSamples => (0.1 * sampleRateHz).round();

  // 1.5 s, or 1.5 x the usual interval when the heart is slow (40 bpm = 1.5 s between beats)
  int get _searchBackSamples {
    int limit = (_searchBackSeconds * sampleRateHz).round();
    if (_rrIntervals.isEmpty) return limit;
    List<int> sorted = List.of(_rrIntervals)..sort();
    return max(limit, (1.5 * sorted[sorted.length ~/ 2]).round());
  }

  // the top of the R wave: the biggest |input| from a bit before the hump to its end
  void _findR(int endIndex) {
    int from = _humpStart - _lookBackSamples;
    int? last = _lastBeat;
    if (last != null && from <= last) from = last + 1;   // never the previous beat again
    if (endIndex - from >= _history.length) from = endIndex - _history.length + 1;   // only what is kept
    _humpRAmplitude = 0;
    _humpRIndex = endIndex;
    for (int k = from; k <= endIndex; k++) {
      double v = _history[k % _history.length].abs();
      if (v > _humpRAmplitude) {
        _humpRAmplitude = v;
        _humpRIndex = k;
      }
    }
  }

  // a hump that was no beat teaches the noise level (1/8 new, 7/8 old)
  // like the beat level, one hump counts at most as 3x the beat level:
  // without it ONE broken sample of -100 mV (its ringing is a wide hump 1000x a beat) lifted
  // the noise level so high that the threshold stayed above all beats for 13 s,
  // the searchback can't help there, it never lowers the beat level below 2x the noise level
  void _learnNoise(double hump) {
    double limit = 3 * _signalLevel;
    _noiseLevel = 0.125 * min(hump, limit) + 0.875 * _noiseLevel;
  }

  // the hump is over: was it a beat?
  bool _endOfHump() {
    // a real QRS is at least ~0.15 mV high and steep, otherwise = noise, even if it is the biggest around
    // too flat (slope is the change over 2 samples, so per second it is * sampleRate / 2)
    bool tooSlow = _humpMaxSlope * sampleRateHz / 2 < _minSlopeMillivoltsPerSecond;
    if (_humpRAmplitude < _minRMillivolts || tooSlow) {
      _learnNoise(_humpMax);
      return false;
    }
    // a beat: the beat level follows it slowly (1/8 new, 7/8 old)
    // a huge hump (moving the cable, 10-100x a beat) would lift the level so high that the next
    // real beats stay under the threshold for many seconds, so one hump counts at most as 3x the level
    // (= the level grows max 25 % per beat, bigger beats after moving an electrode still get there)
    _signalLevel = 0.125 * min(_humpMax, 3 * _signalLevel) + 0.875 * _signalLevel;
    int? last = _lastBeat;
    if (last != null) {
      int rr = _humpRIndex - last;
      // only believable intervals, a 2 s gap is lost signal or a missed beat
      if (rr >= _minRrSeconds * sampleRateHz && rr <= _maxRrSeconds * sampleRateHz) {
        _rrIntervals.add(rr);
        if (_rrIntervals.length > _rrToKeep) _rrIntervals.removeAt(0);
      }
    }
    _lastBeat = _humpRIndex;
    _lastLevelChange = _humpRIndex;
    return true;
  }

  // heart rate in beats per minute, null = not known yet (or the signal was lost)
  int? get bpm {
    int? last = _lastBeat;
    if (_rrIntervals.length < _rrNeeded || last == null) return null;
    if (_lastSample - last > _timeoutSeconds * sampleRateHz) return null;   // electrode off?
    // median: one wrong interval (a missed or an extra beat) doesn't move it
    List<int> sorted = List.of(_rrIntervals)..sort();
    int medianRr = sorted[sorted.length ~/ 2];
    return (60 * sampleRateHz / medianRr).round();
  }

  // sample number of the last beat (its R wave), null before the first one
  int? get lastBeat => _lastBeat;

  // true = the last intervals look like a heart: at least 3, all within 35 % of their median
  // (breathing changes a healthy rhythm by ~10-20 %, noise from loose inputs gives random intervals)
  bool get rhythmSteady {
    if (_rrIntervals.length < _rrNeeded) return false;
    List<int> sorted = List.of(_rrIntervals)..sort();
    int median = sorted[sorted.length ~/ 2];
    return _rrIntervals.every((rr) => (rr - median).abs() <= 0.35 * median);
  }

  // ---- a whole saved recording at once, static, so they can run in the background isolate ----

  // sample numbers of all R waves in a filtered recording
  static List<int> findBeats(List<double> filteredMillivolts, int sampleRateHz) {
    HeartRateDetector detector = HeartRateDetector(sampleRateHz);
    List<int> beats = [];
    for (int i = 0; i < filteredMillivolts.length; i++) {
      if (detector.addSample(i, filteredMillivolts[i])) beats.add(detector.lastBeat!);
    }
    return beats;
  }

  // average heart rate of the beats, null = fewer than 3 believable intervals
  // intervals more than 30% away from the median are left out: a missed beat (double interval)
  // or a lost packet gap would pull a plain average down
  static int? averageBpm(List<int> beats, int sampleRateHz) {
    List<int> rr = [];
    for (int k = 1; k < beats.length; k++) {
      int interval = beats[k] - beats[k - 1];
      if (interval >= _minRrSeconds * sampleRateHz && interval <= _maxRrSeconds * sampleRateHz) {
        rr.add(interval);
      }
    }
    if (rr.length < _rrNeeded) return null;

    List<int> sorted = List.of(rr)..sort();
    int median = sorted[sorted.length ~/ 2];
    List<int> typical = rr.where((r) => (r - median).abs() <= 0.3 * median).toList();
    double mean = typical.reduce((a, b) => a + b) / typical.length;
    return (60 * sampleRateHz / mean).round();
  }

  // heart rate in a part of the recording (the 5 s on the chart), from..to in samples
  static int? bpmBetween(List<int> beats, int from, int to, int sampleRateHz) =>
      averageBpm(beats.where((b) => b >= from && b < to).toList(), sampleRateHz);

  // a new recording starts from zero
  void reset() {
    _window.fillRange(0, _window.length, 0);
    _history.fillRange(0, _history.length, 0);
    _bandHigh.reset();
    _bandLow.reset();
    _m1 = _m2 = 0;
    _lastLevelChange = 0;
    _windowPos = 0;
    _windowSum = 0;
    _samplesSeen = 0;
    _learningMax = 0;
    _x1 = _x2 = _i1 = _i2 = 0;
    _signalLevel = _noiseLevel = 0;
    _inHump = false;
    _lastBeat = null;
    _lastSample = 0;
    _rrIntervals.clear();
  }
}

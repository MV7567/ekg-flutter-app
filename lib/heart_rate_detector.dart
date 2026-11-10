import 'dart:typed_data';   // Float64List

// finds the heart beats (R waves) in the EKG and gives the heart rate in beats per minute
// a simplified Pan-Tompkins algorithm (1985), the classic QRS detector:
//   1. derivative   - the QRS is the steepest part of the EKG, P and T waves are slow
//   2. square       - only positive values, big slopes become much bigger than small ones,
//                     and spikes pointing down count the same as spikes pointing up
//   3. moving sum   - over 150 ms (the width of a QRS), one smooth hump per beat
//   4. threshold    - a hump higher than the threshold is a beat, the threshold follows
//                     the height of the last beats and of the noise (adapts to the person)
//   5. refractory   - no second beat within 250 ms (the heart can't, max 240 bpm)
// input: the FILTERED signal in mV (the display filter: no DC, no 50 Hz, no wander)
class HeartRateDetector {
  HeartRateDetector(this.sampleRateHz)
      : _window = Float64List((0.150 * sampleRateHz).round()),
        _refractorySamples = (0.250 * sampleRateHz).round(),
        _learningSamples = 2 * sampleRateHz;

  final int sampleRateHz;

  final Float64List _window;        // last 150 ms of squared slopes, ring buffer
  int _windowPos = 0;
  double _windowSum = 0;

  final int _refractorySamples;     // 250 ms
  final int _learningSamples;       // the first 2 s only measure how high the beats are
  int _samplesSeen = 0;
  double _learningMax = 0;

  double _x1 = 0, _x2 = 0;          // the last two input samples, for the derivative
  double _i1 = 0, _i2 = 0;          // the last two values of the moving sum, to find its peaks

  double _signalLevel = 0;          // typical height of a beat hump (SPKI in Pan-Tompkins)
  double _noiseLevel = 0;           // typical height of the other humps (NPKI)

  // the hump of the moving sum that is above the threshold right now (a QRS candidate)
  bool _inHump = false;
  int _humpStart = 0;
  double _humpMax = 0;              // highest value of the moving sum in this hump
  double _humpRAmplitude = 0;       // highest |EKG| in this hump, the R wave
  int _humpRIndex = 0;              // and where it was = the time of the beat

  int? _lastBeat;                   // sample number of the last beat (its R wave)
  int _lastSample = 0;
  final List<int> _rrIntervals = [];   // last RR intervals in samples (time between beats)

  static const int _rrToKeep = 5;          // bpm = median of the last 5 intervals
  static const int _rrNeeded = 3;          // bpm shown only after 3 intervals (4 beats), not after one lucky one
  static const double _minRMillivolts = 0.15;
  static const double _minRrSeconds = 0.3; // 200 bpm
  static const double _maxRrSeconds = 2.0; // 30 bpm, a longer gap = lost signal, not a beat
  static const double _timeoutSeconds = 3; // no beat for 3 s -> bpm unknown

  // one filtered sample, sampleIndex counts the lost packets too (the real time)
  // returns true when this sample finished a beat
  bool addSample(int sampleIndex, double millivolts) {
    _lastSample = sampleIndex;

    // 1. derivative over 2 samples (8 ms), 2. square
    double slope = millivolts - _x2;
    _x2 = _x1;
    _x1 = millivolts;
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
    if (_samplesSeen <= _learningSamples) {
      // learning: in 2 s there are at least 1-2 beats, the highest hump is a beat
      if (integrated > _learningMax) _learningMax = integrated;
      if (_samplesSeen == _learningSamples) {
        _signalLevel = 0.5 * _learningMax;
        _noiseLevel = 0.05 * _learningMax;
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
      if (millivolts.abs() > _humpRAmplitude) {
        _humpRAmplitude = millivolts.abs();
        _humpRIndex = sampleIndex;
      }
      // the hump ends when the sum falls under the threshold (or after 300 ms, wider is no QRS)
      if (integrated < threshold || sampleIndex - _humpStart > 0.3 * sampleRateHz) {
        _inHump = false;
        return _endOfHump();
      }
      return false;
    }

    if (integrated > threshold &&
        (_lastBeat == null || sampleIndex - _lastBeat! > _refractorySamples)) {
      // a new hump starts
      _inHump = true;
      _humpStart = sampleIndex;
      _humpMax = integrated;
      _humpRAmplitude = millivolts.abs();
      _humpRIndex = sampleIndex;
      return false;
    }

    // a smaller hump that never reached the threshold (T wave, noise): it teaches the noise level
    if (isPeak && peak <= threshold) _noiseLevel = 0.125 * peak + 0.875 * _noiseLevel;
    return false;
  }

  // the hump is over: was it a beat?
  bool _endOfHump() {
    // a real QRS is at least ~0.15 mV high, smaller = noise, even if it is the biggest around
    if (_humpRAmplitude < _minRMillivolts) {
      _noiseLevel = 0.125 * _humpMax + 0.875 * _noiseLevel;
      return false;
    }
    // a beat: the beat level follows it slowly (1/8 new, 7/8 old)
    _signalLevel = 0.125 * _humpMax + 0.875 * _signalLevel;
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

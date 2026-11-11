import 'dart:typed_data';   // Float64List

// how good the EKG signal is right now, worst problems first in the checks below
enum SignalQuality {
  checking,       // the first 2 s, not enough data yet
  good,           // clean signal with regular beats
  noisy,          // a lot of fast wiggling: muscles, moving, a loose electrode
  noBeats,        // a signal, but no heart beat for 3 s: electrodes in a wrong place?
  flat,           // almost a straight line: nothing is connected
  electrodeOff,   // the raw signal is huge or at the edge of the ADC range: an electrode is off
}

// looks at the last 2 s of the signal and says how good it is
// it doesn't need the hardware lead-off detection of the ADS1194, everything is guessed
// from the samples, so the limits below are estimates, to be tuned with real electrodes
class SignalQualityMonitor {
  SignalQualityMonitor(this.sampleRateHz, {required this.adcLimitMillivolts})
      : _raw = Float64List(2 * sampleRateHz),
        _filtered = Float64List(2 * sampleRateHz),
        _slopes = Float64List(2 * sampleRateHz);

  final int sampleRateHz;
  // the biggest value the ADC can give, in mV, a sample near it = the input is out of range
  final double adcLimitMillivolts;

  // the last 2 s, ring buffers like in the heart rate detector
  final Float64List _raw;        // before the filter (with DC, hum, wander)
  final Float64List _filtered;   // after the display filter, what the chart shows
  final Float64List _slopes;     // |difference to the previous filtered sample|
  int _pos = 0;
  int _seen = 0;
  int _sinceCheck = 0;   // samples since the last check
  double _lastFiltered = 0;

  SignalQuality _quality = SignalQuality.checking;
  SignalQuality get quality => _quality;

  // the limits, in mV
  static const double _maxRawPeakToPeak = 50;   // a real EKG + wander is a few mV, mains hum on a loose cable is much more
  static const double _minPeakToPeak = 0.05;    // under that the filtered signal is a straight line
  static const double _maxTypicalSlope = 0.03;  // typical step between samples, a clean EKG is mostly flat between the beats
  static const double _noBeatSeconds = 3;       // the same timeout as the heart rate

  // one sample: raw = mV before the filter, filtered = after it, the same as for the chart
  void addSample(double raw, double filtered) {
    _raw[_pos] = raw;
    _filtered[_pos] = filtered;
    _slopes[_pos] = _seen == 0 ? 0 : (filtered - _lastFiltered).abs();
    _lastFiltered = filtered;
    _pos = (_pos + 1) % _raw.length;
    _seen++;
    _sinceCheck++;
  }

  // checks the last 2 s, called after every packet
  // samplesSinceLastBeat: from the heart rate detector, null = no beat found yet
  // the check is done only every 0.5 s, so the text doesn't flicker 25 times per second
  SignalQuality update(int? samplesSinceLastBeat) {
    if (_seen < _raw.length) return _quality = SignalQuality.checking;
    if (_quality != SignalQuality.checking && _sinceCheck < sampleRateHz ~/ 2) return _quality;   // checked less than 0.5 s ago
    _sinceCheck = 0;
    _quality = _check(samplesSinceLastBeat);
    return _quality;
  }

  SignalQuality _check(int? samplesSinceLastBeat) {
    // 1. raw signal at the edge of the ADC or swinging wildly: an electrode is off
    double rawMin = _raw[0], rawMax = _raw[0];
    for (double x in _raw) {
      if (x < rawMin) rawMin = x;
      if (x > rawMax) rawMax = x;
    }
    if (rawMax >= adcLimitMillivolts || rawMin <= -adcLimitMillivolts) return SignalQuality.electrodeOff;
    if (rawMax - rawMin > _maxRawPeakToPeak) return SignalQuality.electrodeOff;

    // 2. filtered signal is a straight line: nothing reaches the input
    double min = _filtered[0], max = _filtered[0];
    for (double x in _filtered) {
      if (x < min) min = x;
      if (x > max) max = x;
    }
    if (max - min < _minPeakToPeak) return SignalQuality.flat;

    // 3. noise: the MEDIAN slope, the QRS is steep but short (~10 % of the time),
    //    so the median shows the part between the beats, which should be calm
    List<double> sorted = List.of(_slopes)..sort();
    if (sorted[sorted.length ~/ 2] > _maxTypicalSlope) return SignalQuality.noisy;

    // 4. no beat for 3 s, and the signal itself looks fine
    // no beat yet at all: counted from the start of the recording, so the first seconds
    // (the detector is still learning) are not reported as a problem
    int since = samplesSinceLastBeat ?? _seen;
    if (since > _noBeatSeconds * sampleRateHz) {
      return SignalQuality.noBeats;
    }
    return SignalQuality.good;
  }

  // a new recording starts from zero
  void reset() {
    _raw.fillRange(0, _raw.length, 0);
    _filtered.fillRange(0, _filtered.length, 0);
    _slopes.fillRange(0, _slopes.length, 0);
    _pos = 0;
    _seen = 0;
    _sinceCheck = 0;
    _lastFiltered = 0;
    _quality = SignalQuality.checking;
  }
}

import 'dart:math';

// "biquad" IIR filter: every output sample is calculated from
// the current input, the 2 previous inputs and the 2 previous outputs:
//   y = b0*x + b1*x1 + b2*x2 - a1*y1 - a2*y2
// only the 5 coefficients decide what the filter does (notch, low-pass, ...)
// formulas from the "Audio EQ Cookbook" (R. Bristow-Johnson)
class BiquadFilter {
  BiquadFilter._(this._b0, this._b1, this._b2, this._a1, this._a2);

  // notch (band-stop): removes one frequency, lets the rest through
  // q: bigger = narrower notch, 5 -> about 10 Hz wide around 50 Hz
  factory BiquadFilter.notch({
    required double frequencyHz,
    required double sampleRateHz,
    double q = 5,
  }) {
    double w0 = 2 * pi * frequencyHz / sampleRateHz;   // frequency as an angle per sample
    double alpha = sin(w0) / (2 * q);
    double cosW0 = cos(w0);
    double a0 = 1 + alpha;
    // everything is divided by a0, so the formula in process() is simpler
    return BiquadFilter._(1 / a0, -2 * cosW0 / a0, 1 / a0, -2 * cosW0 / a0, (1 - alpha) / a0);
  }

  // low-pass: lets slow changes through, removes everything above frequencyHz
  // q = 0.7071 -> "Butterworth", flat until the cut-off frequency, no overshoot
  factory BiquadFilter.lowPass({
    required double frequencyHz,
    required double sampleRateHz,
    double q = 0.7071,
  }) {
    double w0 = 2 * pi * frequencyHz / sampleRateHz;
    double alpha = sin(w0) / (2 * q);
    double cosW0 = cos(w0);
    double a0 = 1 + alpha;
    return BiquadFilter._((1 - cosW0) / 2 / a0, (1 - cosW0) / a0, (1 - cosW0) / 2 / a0,
        -2 * cosW0 / a0, (1 - alpha) / a0);
  }

  // high-pass: removes everything slower than frequencyHz (offset, slow drift of the line),
  // lets faster changes through - the mirror image of the low-pass
  factory BiquadFilter.highPass({
    required double frequencyHz,
    required double sampleRateHz,
    double q = 0.7071,
  }) {
    double w0 = 2 * pi * frequencyHz / sampleRateHz;
    double alpha = sin(w0) / (2 * q);
    double cosW0 = cos(w0);
    double a0 = 1 + alpha;
    return BiquadFilter._((1 + cosW0) / 2 / a0, -(1 + cosW0) / a0, (1 + cosW0) / 2 / a0,
        -2 * cosW0 / a0, (1 - alpha) / a0);
  }

  // filter coefficients, calculated once
  final double _b0, _b1, _b2, _a1, _a2;

  // memory of the filter: 2 previous inputs (x) and 2 previous outputs (y)
  double _x1 = 0, _x2 = 0, _y1 = 0, _y2 = 0;

  // filter one sample, call it for every sample in order
  double process(double x) {
    double y = _b0 * x + _b1 * _x1 + _b2 * _x2 - _a1 * _y1 - _a2 * _y2;

    // shift the memory: the current values become the "previous" ones
    _x2 = _x1;
    _x1 = x;
    _y2 = _y1;
    _y1 = y;
    return y;
  }

  // forget the old samples, e.g. when a new recording starts
  void reset() {
    _x1 = _x2 = _y1 = _y2 = 0;
  }

  // pretend the filter has already been getting the constant value "input" for a long time
  // and has settled at "output" - this avoids the big jump at the start
  void prime(double input, double output) {
    _x1 = _x2 = input;
    _y1 = _y2 = output;
  }
}

// the filters used for the EKG chart, one after another:
//  1. high-pass 0.5 Hz - removes the offset (~ -9 mV) and the slow drift of the line (breathing, movement)
//  2. notch 50 Hz  - mains hum
//  3. notch 100 Hz - 2nd harmonic of the mains hum (the hum is not a clean sine)
//  4. low-pass 40 Hz - remaining fast noise, the EKG has almost nothing above 40 Hz
class EkgDisplayFilter {
  EkgDisplayFilter(double sampleRateHz)
      : _highPass = BiquadFilter.highPass(frequencyHz: 0.5, sampleRateHz: sampleRateHz),
        _notch50 = BiquadFilter.notch(frequencyHz: 50, sampleRateHz: sampleRateHz),
        _notch100 = BiquadFilter.notch(frequencyHz: 100, sampleRateHz: sampleRateHz),
        _lowPass = BiquadFilter.lowPass(frequencyHz: 40, sampleRateHz: sampleRateHz);

  final BiquadFilter _highPass, _notch50, _notch100, _lowPass;

  // false until the first sample arrives
  bool _primed = false;

  double process(double x) {
    if (!_primed) {
      // the first sample is taken as the offset: the high-pass behaves as if it had
      // been removing it for a long time, so its output starts at 0 instead of jumping
      // (the other filters start at 0 too, so they also get no jump)
      _highPass.prime(x, 0);
      _primed = true;
    }
    return _lowPass.process(_notch100.process(_notch50.process(_highPass.process(x))));
  }

  void reset() {
    _highPass.reset();
    _notch50.reset();
    _notch100.reset();
    _lowPass.reset();
    _primed = false;
  }
}

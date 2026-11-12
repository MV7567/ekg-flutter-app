import 'dart:math';   // pi, sin, cos....

// "biquad" IIR filter: every output sample is calculated from
// the current input, the 2 previous inputs and the 2 previous outputs:
//   y = b0*x + b1*x1 + b2*x2 - a1*y1 - a2*y2
// only the 5 coefficients decide what the filter does (notch, low-pass, ...)
// formulas from the "Audio EQ Cookbook" (R. Bristow-Johnson)

// x is the current input sample (raw mV)
// x1 and x2 are the 2 previous input samples
// y1, y2 are the 2 previous output samples (what the filter calculated before)
// since it uses its own previous outputs its an IIR filter (infinite impulse response) 
// Biquad means it has 2 previous values on each side 

class BiquadFilter {
  BiquadFilter._(this._b0, this._b1, this._b2, this._a1, this._a2);

  // notch (band-stop): removes one frequency, lets the rest through
  // q: bigger = narrower notch, 5 -> about 10 Hz wide around 50 Hz
  factory BiquadFilter.notch({    // kind of contructor, firs tit calculates then it calls BiquadFilter._(...), and returns a ready object
    required double frequencyHz,
    required double sampleRateHz,
    double q = 5,
  }) {
    var (cosW0, alpha, a0) = _common(frequencyHz, sampleRateHz, q);
    // everything is divided by a0, so the formula in process() is simpler
    return BiquadFilter._(1 / a0, -2 * cosW0 / a0, 1 / a0, -2 * cosW0 / a0, (1 - alpha) / a0);
  }

  // low-pass: lets slow changes through, removes everything above frequencyHz
  // q = 0.7071 -> "Butterworth", flat until the cut-off frequency, no peak in the frequency response 
  factory BiquadFilter.lowPass({
    required double frequencyHz,
    required double sampleRateHz,
    double q = 0.7071,
  }) {
    var (cosW0, alpha, a0) = _common(frequencyHz, sampleRateHz, q);
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
    var (cosW0, alpha, a0) = _common(frequencyHz, sampleRateHz, q);
    return BiquadFilter._((1 + cosW0) / 2 / a0, -(1 + cosW0) / a0, (1 + cosW0) / 2 / a0,
        -2 * cosW0 / a0, (1 - alpha) / a0);
  }

  // the part that is the same for every filter type, returns 3 values at once (a "record"), since dart function can turn one thing, record makes it so that one thing is actually 3 things
  static (double cosW0, double alpha, double a0) _common(
      double frequencyHz, double sampleRateHz, double q) {
    // a digital filter only works between 0 and half the sample rate (Nyquist, 125 Hz at 250 SPS):
    // exactly at fs/2 the filter starts to oscillate by itself, above it the wrong frequency is filtered
    assert(frequencyHz > 0 && frequencyHz < sampleRateHz / 2,
        'filter frequency $frequencyHz Hz must be between 0 and ${sampleRateHz / 2} Hz');   // debug only, check the frequency, all in one spot
    double w0 = 2 * pi * frequencyHz / sampleRateHz;   // frequency as an angle per sample
    double alpha = sin(w0) / (2 * q);                  // width of the filter, bigger q gives smaller alpha and narrower notch
    double cosW0 = cos(w0);
    double a0 = 1 + alpha;
    return (cosW0, alpha, a0);
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

// the filters used for the EKG chart, one after another: Connects 4 biquad filters for the chart
//  1. high-pass 0.5 Hz - removes the offset (~ -9 mV) and the slow drift of the line (breathing, movement)
//  2. notch 50 Hz  - mains hum, TWICE: the mains is often 49.9 Hz, not exactly 50, there one notch
//                    removes "only" ~99 % (a 3 mV hum left 0.03 mV of ripple in a real recording),
//                    two in a row ~99.99 %, the EKG below 40 Hz loses only a few %
//  3. notch 100 Hz - 2nd harmonic of the mains hum (the hum is not a clean sine)
//  4. low-pass 40 Hz - remaining fast noise, the EKG has almost nothing above 40 Hz
class EkgDisplayFilter {
  EkgDisplayFilter(double sampleRateHz)
      : _highPass = BiquadFilter.highPass(frequencyHz: 0.5, sampleRateHz: sampleRateHz),
        _notch50 = BiquadFilter.notch(frequencyHz: 50, sampleRateHz: sampleRateHz),
        _notch50Again = BiquadFilter.notch(frequencyHz: 50, sampleRateHz: sampleRateHz),
        // 100 Hz can only be filtered below the Nyquist frequency (needs more than 200 SPS),
        // otherwise null = no 100 Hz notch (at lower rates the low-pass already removes it)
        _notch100 = 100 < sampleRateHz / 2
            ? BiquadFilter.notch(frequencyHz: 100, sampleRateHz: sampleRateHz)
            : null,
        _lowPass = BiquadFilter.lowPass(frequencyHz: 40, sampleRateHz: sampleRateHz);

  final BiquadFilter _highPass, _notch50, _notch50Again, _lowPass;
  final BiquadFilter? _notch100;

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
    double y = _notch50Again.process(_notch50.process(_highPass.process(x)));
    if (_notch100 != null) y = _notch100.process(y);
    return _lowPass.process(y);
  }

  void reset() {
    _highPass.reset();
    _notch50.reset();
    _notch50Again.reset();
    _notch100?.reset();
    _lowPass.reset();
    _primed = false;
  }
}

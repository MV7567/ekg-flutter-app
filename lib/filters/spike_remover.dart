// removes a single impossible sample (a "spike") before the filters
// a real recording had ONE sample of -100 mV between normal values of ~1 mV: the ESP32 read the
// ADS1194 too late and got a frame mixed from two samples. the filters turned this one sample into
// 0.2 s of ringing, the quality showed "electrode off" and the detector missed beats for 13 s
//
// how: the body can't change the voltage by 20 mV in 4 ms (a QRS is ~1 mV in 40 ms,
// even a 3 mV mains hum changes by only ~4 mV per sample), so a bigger jump is suspicious:
//  - the suspicious sample is replaced by the last good one (held for one sample)
//  - if the NEXT sample is back near the old value -> it was a spike, it never reaches the filters
//  - if the next sample stays far away -> it was a real step (an electrode moved),
//    it is let through, only one sample (4 ms) late
// no delay for normal samples, so the live chart and the beat times stay exactly where they were
// the CSV file still gets the raw values (what the device really sent), this only cleans the display
class SpikeRemover {
  // the biggest believable change between two samples, 20 mV = ~3300 ADC steps at gain 12
  static const double maxJumpMillivolts = 20;

  double? _last;           // the last sample let through, null before the first
  bool _holding = false;   // true = the previous sample was replaced, the next one is let through

  int removed = 0;         // how many samples were replaced (for tests and debugging)

  double process(double millivolts) {
    double? last = _last;
    if (last == null) {
      _last = millivolts;
      return millivolts;
    }
    if (!_holding && (millivolts - last).abs() > maxJumpMillivolts) {
      // suspicious: show the last good value instead, decide with the next sample
      _holding = true;
      removed++;
      return last;
    }
    // normal sample, or the one after a suspicious one (a real step is accepted here)
    _holding = false;
    _last = millivolts;
    return millivolts;
  }

  void reset() {
    _last = null;
    _holding = false;
    removed = 0;
  }
}

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/filters/biquad_filter.dart';

const fs = 250.0;

// sends a sine wave (amplitude 1) through the filter and returns the biggest output value
// after the filter has settled (the first 2 seconds are skipped)
// sampleRate is optional, by default the 250 SPS of the ADS1194
double outputAmplitude(double Function(double) filter, double frequencyHz,
    {double sampleRate = fs}) {
  double maxOut = 0;
  for (int i = 0; i < sampleRate * 4; i++) {
    double y = filter(sin(2 * pi * frequencyHz * i / sampleRate));
    if (i > sampleRate * 2) maxOut = max(maxOut, y.abs());
  }
  return maxOut;
}

void main() {
  test('notch removes 50 Hz and the measured 49.9 Hz', () {
    expect(outputAmplitude(BiquadFilter.notch(frequencyHz: 50, sampleRateHz: fs).process, 50),
        lessThan(0.01));
    expect(outputAmplitude(BiquadFilter.notch(frequencyHz: 50, sampleRateHz: fs).process, 49.9),
        lessThan(0.05));
  });

  test('low-pass 40 Hz keeps slow signals and removes fast ones', () {
    expect(outputAmplitude(BiquadFilter.lowPass(frequencyHz: 40, sampleRateHz: fs).process, 5),
        greaterThan(0.98));
    expect(outputAmplitude(BiquadFilter.lowPass(frequencyHz: 40, sampleRateHz: fs).process, 110),
        lessThan(0.15));
  });

  test('EKG display filter: hum removed, EKG frequencies kept', () {
    expect(outputAmplitude(EkgDisplayFilter(fs).process, 49.9), lessThan(0.05));
    expect(outputAmplitude(EkgDisplayFilter(fs).process, 99.8), lessThan(0.05));
    expect(outputAmplitude(EkgDisplayFilter(fs).process, 1), greaterThan(0.95));   // P, T waves
    expect(outputAmplitude(EkgDisplayFilter(fs).process, 15), greaterThan(0.75));  // QRS
  });

  test('EKG display filter: mains slightly off 50 Hz is removed too (two notches)', () {
    // real recording 17:34: 3.2 mV hum at 49.9 Hz left 0.033 mV of ripple with one notch,
    // that made the signal look "noisy"; mains may be 49.8 - 50.2 Hz
    for (double hz in [49.8, 49.9, 50.0, 50.1, 50.2]) {
      // 1 here = 1 mV of hum in, under 0.003 -> a 3 mV hum leaves under 0.01 mV
      expect(outputAmplitude(EkgDisplayFilter(fs).process, hz), lessThan(0.003), reason: '$hz Hz');
    }
    expect(outputAmplitude(EkgDisplayFilter(fs).process, 30), greaterThan(0.6));   // the fast part of the QRS
  });

  test('high-pass 0.5 Hz removes offset and slow drift', () {
    expect(outputAmplitude(BiquadFilter.highPass(frequencyHz: 0.5, sampleRateHz: fs).process, 0.05),
        lessThan(0.05));
    expect(outputAmplitude(BiquadFilter.highPass(frequencyHz: 0.5, sampleRateHz: fs).process, 5),
        greaterThan(0.98));
  });

  test('EKG display filter: -9 mV offset gives no jump at the start', () {
    final filter = EkgDisplayFilter(fs);
    double maxOut = 0;
    for (int i = 0; i < fs * 4; i++) {
      // offset -9 mV + small 1 Hz wave (0.3 mV)
      double y = filter.process(-9 + 0.3 * sin(2 * pi * 1 * i / fs));
      maxOut = max(maxOut, y.abs());
    }
    expect(maxOut, lessThan(0.5));   // without priming the start would jump by several mV
  });

  test('frequency at or above half the sample rate is an error (debug mode)', () {
    expect(() => BiquadFilter.notch(frequencyHz: 125, sampleRateHz: fs),
        throwsA(isA<AssertionError>()));   // exactly Nyquist
    expect(() => BiquadFilter.lowPass(frequencyHz: 0, sampleRateHz: fs),
        throwsA(isA<AssertionError>()));
  });

  test('EKG display filter works at 125 SPS (no 100 Hz notch then)', () {
    const slowFs = 125.0;
    expect(outputAmplitude(EkgDisplayFilter(slowFs).process, 49.9, sampleRate: slowFs),
        lessThan(0.05));      // hum still removed
    expect(outputAmplitude(EkgDisplayFilter(slowFs).process, 1, sampleRate: slowFs),
        greaterThan(0.95));   // EKG kept, filter does not oscillate
  });
}

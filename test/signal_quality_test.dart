import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/ekg_config.dart';
import 'package:ecg_ble_app/ekg_test_signal.dart';
import 'package:ecg_ble_app/filters/biquad_filter.dart';
import 'package:ecg_ble_app/filters/spike_remover.dart';
import 'package:ecg_ble_app/heart_rate_detector.dart';
import 'package:ecg_ble_app/signal_quality.dart';

const int fs = sampleRateHz;
const double adcLimit = 32000 * millivoltsPerLsb;   // like the device screen

// runs [seconds] of signal(t) in mV like the device screen does:
// spike remover -> filter -> heart rate detector + quality monitor, the result after the last packet
SignalQuality run(double Function(double t) signal, double seconds) {
  SpikeRemover spikeRemover = SpikeRemover();
  EkgDisplayFilter filter = EkgDisplayFilter(fs.toDouble());
  HeartRateDetector detector = HeartRateDetector(fs);
  SignalQualityMonitor monitor = SignalQualityMonitor(fs, adcLimitMillivolts: adcLimit);
  SignalQuality quality = SignalQuality.checking;
  int n = (seconds * fs).round();
  for (int i = 0; i < n; i++) {
    double raw = spikeRemover.process(signal(i / fs));
    double filtered = filter.process(raw);
    detector.addSample(i, filtered);
    monitor.addSample(raw, filtered);
    if (i % samplesPerPacket == samplesPerPacket - 1) {   // after every packet of 10
      int? last = detector.lastBeat;
      quality = monitor.update(last == null ? null : i - last, rhythmSteady: detector.rhythmSteady);
    }
  }
  return quality;
}

void main() {
  Random random = Random(1);   // fixed seed
  double noise(double mv) => mv * (random.nextDouble() * 2 - 1);   // -mv .. +mv

  test('the first 2 s: still checking', () {
    expect(run(EkgTestSignal.millivoltsAt, 1.5), SignalQuality.checking);
  });

  test('test signal (with DC, wander and hum): good', () {
    expect(run(EkgTestSignal.millivoltsAt, 10), SignalQuality.good);
  });

  test('the first seconds of a good signal are not "no beats"', () {
    // after 2.5 s the detector is still learning, it is not a problem yet
    expect(run(EkgTestSignal.millivoltsAt, 2.5), isNot(SignalQuality.noBeats));
  });

  test('3-4 s: the detector has just finished learning, no warning yet', () {
    // the real recording 17:11 showed "no beats" for a moment at 3.0-3.6 s
    for (double seconds in [3.0, 3.5, 4.0]) {
      expect(run(EkgTestSignal.millivoltsAt, seconds), SignalQuality.checking, reason: '$seconds s');
    }
  });

  test('a little noise (0.01 mV) is still good', () {
    expect(run((t) => EkgTestSignal.millivoltsAt(t) + noise(0.01), 10), SignalQuality.good);
  });

  test('muscle noise (0.2 mV): noisy', () {
    expect(run((t) => EkgTestSignal.millivoltsAt(t) + noise(0.2), 10), SignalQuality.noisy);
  });

  test('straight line: flat', () {
    expect(run((t) => -5.0, 10), SignalQuality.flat);
  });

  test('slow waves without beats (breathing only): no beats', () {
    expect(run((t) => 0.5 * sin(2 * pi * 1 * t), 10), SignalQuality.noBeats);
  });

  test('beats that stop (electrode slides off the skin): no beats after 3 s', () {
    expect(run((t) => t < 6 ? EkgTestSignal.millivoltsAt(t) : 0.3 * sin(2 * pi * 0.5 * t), 12),
        SignalQuality.noBeats);
  });

  test('loose cable: huge mains hum -> electrode off', () {
    expect(run((t) => EkgTestSignal.millivoltsAt(t) + 40 * sin(2 * pi * 50 * t), 10),
        SignalQuality.electrodeOff);
  });

  test('input at the edge of the ADC -> electrode off', () {
    expect(run((t) => 200.0, 10), SignalQuality.electrodeOff);   // 200 mV = full scale at gain 12
  });

  test('reset: checking again', () {
    SignalQualityMonitor monitor = SignalQualityMonitor(fs, adcLimitMillivolts: adcLimit);
    for (int i = 0; i < 5 * fs; i++) {
      monitor.addSample(0, 0);
    }
    expect(monitor.update(null), SignalQuality.flat);
    monitor.reset();
    expect(monitor.update(null), SignalQuality.checking);
  });

  test('real-like: no electrodes (floating inputs) is NOT "good"', () {
    // like the recording without electrodes: 42 mV offset, a little hum, random wiggling
    Random loose = Random(3);
    double floating(double t) => 42 + 0.17 * sin(2 * pi * 49.9 * t) + 0.15 * (loose.nextDouble() - 0.5);
    expect(run(floating, 5), isNot(SignalQuality.good));   // never "good", not even at the start
    expect(run(floating, 15), SignalQuality.noBeats);
  });

  test('real-like: small QRS under a big hum is "good"', () {
    expect(run((t) => 0.2 * EkgTestSignal.cleanEkgAt(t) + 2.0 * sin(2 * pi * 49.92 * t), 20),
        SignalQuality.good);
  });

  test('real-like: ONE broken sample of -100 mV does not say "electrode off"', () {
    // the recording 2026-11-12 16:23: one frame mixed from two samples in the device
    double withSpike(double t) => (t * fs).round() == 7 * fs ? -100.0 : EkgTestSignal.millivoltsAt(t);
    for (double seconds in [7.5, 8.5, 10, 15]) {
      expect(run(withSpike, seconds), SignalQuality.good, reason: '$seconds s');
    }
  });
}

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/ekg_config.dart';
import 'package:ecg_ble_app/ekg_test_signal.dart';
import 'package:ecg_ble_app/filters/biquad_filter.dart';
import 'package:ecg_ble_app/heart_rate_detector.dart';
import 'package:ecg_ble_app/signal_quality.dart';

const int fs = sampleRateHz;
const double adcLimit = 32000 * millivoltsPerLsb;   // like the device screen

// runs [seconds] of signal(t) in mV like the device screen does:
// filter -> heart rate detector + quality monitor, the result after the last packet
SignalQuality run(double Function(double t) signal, double seconds) {
  EkgDisplayFilter filter = EkgDisplayFilter(fs.toDouble());
  HeartRateDetector detector = HeartRateDetector(fs);
  SignalQualityMonitor monitor = SignalQualityMonitor(fs, adcLimitMillivolts: adcLimit);
  SignalQuality quality = SignalQuality.checking;
  int n = (seconds * fs).round();
  for (int i = 0; i < n; i++) {
    double raw = signal(i / fs);
    double filtered = filter.process(raw);
    detector.addSample(i, filtered);
    monitor.addSample(raw, filtered);
    if (i % samplesPerPacket == samplesPerPacket - 1) {   // after every packet of 10
      int? last = detector.lastBeat;
      quality = monitor.update(last == null ? null : i - last);
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
}

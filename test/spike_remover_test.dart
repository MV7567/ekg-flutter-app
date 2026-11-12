import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/ekg_test_signal.dart';
import 'package:ecg_ble_app/filters/spike_remover.dart';

const int fs = 250;

void main() {
  test('one broken sample (-100 mV) is replaced by the previous one', () {
    SpikeRemover remover = SpikeRemover();
    List<double> out = [for (double x in [1.0, 1.2, -100.0, 1.1, 0.9]) remover.process(x)];
    expect(out, [1.0, 1.2, 1.2, 1.1, 0.9]);
    expect(remover.removed, 1);
  });

  test('a real step (electrode moved) is let through, 1 sample late', () {
    SpikeRemover remover = SpikeRemover();
    List<double> out = [for (double x in [0.0, 0.0, 50.0, 50.0, 50.1]) remover.process(x)];
    expect(out, [0.0, 0.0, 0.0, 50.0, 50.1]);
  });

  test('normal EKG with a 3 mV hum is never changed', () {
    SpikeRemover remover = SpikeRemover();
    for (int i = 0; i < 30 * fs; i++) {
      double t = i / fs;
      double x = EkgTestSignal.millivoltsAt(t) + 3 * sin(2 * pi * 49.9 * t) - 9;
      expect(remover.process(x), x);
    }
    expect(remover.removed, 0);
  });

  test('reset forgets the last sample', () {
    SpikeRemover remover = SpikeRemover();
    remover.process(0);
    remover.reset();
    expect(remover.process(80), 80);   // the first sample after reset is never a "jump"
    expect(remover.removed, 0);
  });
}

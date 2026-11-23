import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/af_detector.dart';

const int fs = 250;   // 1 sample = 4 ms

// beat positions (in samples) from a list of intervals in ms, the first beat at 1 s
List<int> beatsFrom(List<int> intervalsMs) {
  List<int> beats = [fs];
  for (int ms in intervalsMs) {
    beats.add(beats.last + ms ~/ 4);
  }
  return beats;
}

// a normal rhythm with breathing: 800 ms +- 8 % in a slow wave (one breath = 5 beats)
List<int> sinus(int count) => [for (int k = 0; k < count; k++) (800 + 64 * sin(2 * pi * k / 5)).round()];

// atrial fibrillation: every interval random between 450 and 1050 ms
List<int> fibrillation(int count, Random random) => [for (int k = 0; k < count; k++) 450 + random.nextInt(600)];

void main() {
  test('a normal rhythm, even with a strong breathing change: no AF', () {
    AfDetector d = AfDetector.analyze(beatsFrom(sinus(150)), fs);
    expect(d.suspected, isFalse);
  });

  test('random intervals for 2 minutes: an AF episode over (almost) all of it', () {
    List<int> beats = beatsFrom(fibrillation(160, Random(3)));
    AfDetector d = AfDetector.analyze(beats, fs);
    expect(d.suspected, isTrue);
    expect(d.seconds(fs), greaterThan(0.9 * (beats.last - beats.first) / fs));
    expect(d.contains(beats[80]), isTrue);
  });

  test('bigeminy and trigeminy (a repeating pattern) are not AF', () {
    List<int> bigeminy = [for (int k = 0; k < 75; k++) ...[520, 1080]];
    List<int> trigeminy = [for (int k = 0; k < 50; k++) ...[800, 520, 1080]];
    expect(AfDetector.analyze(beatsFrom(bigeminy), fs).suspected, isFalse);
    expect(AfDetector.analyze(beatsFrom(trigeminy), fs).suspected, isFalse);
  });

  test('a few single premature beats in a normal rhythm are not AF', () {
    List<int> intervals = sinus(150);
    for (int k = 10; k < 150; k += 12) {
      intervals[k] = 500;
      intervals[k + 1] = 1100;
    }
    expect(AfDetector.analyze(beatsFrom(intervals), fs).suspected, isFalse);
  });

  test('AF shorter than 30 s is not shown, a longer one is, only where it is', () {
    Random random = Random(5);
    List<int> short = [...sinus(60), ...fibrillation(25, random), ...sinus(60)];   // ~19 s of AF
    expect(AfDetector.analyze(beatsFrom(short), fs).suspected, isFalse);

    List<int> long = [...sinus(60), ...fibrillation(80, random), ...sinus(60)];    // ~60 s of AF
    List<int> beats = beatsFrom(long);
    AfDetector d = AfDetector.analyze(beats, fs);
    expect(d.suspected, isTrue);
    expect(d.contains(beats[100]), isTrue);    // in the middle of the AF
    expect(d.contains(beats[10]), isFalse);    // the normal rhythm at the start
    expect(d.contains(beats[195]), isFalse);   // and at the end
  });

  test('a window mostly inside an artifact is not judged', () {
    List<int> beats = beatsFrom(fibrillation(40, Random(7)));
    expect(AfDetector.irregularity(beats, 0, fs), isNotNull);
    expect(AfDetector.irregularity(beats, 0, fs, disturbed: (s) => s < beats[20]), isNull);
  });
}

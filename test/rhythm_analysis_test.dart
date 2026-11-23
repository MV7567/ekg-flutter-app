import 'package:flutter_test/flutter_test.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:ecg_ble_app/af_detector.dart';
import 'package:ecg_ble_app/l10n/app_localizations.dart';
import 'package:ecg_ble_app/rhythm_analysis.dart';
import 'package:ecg_ble_app/rr_stats.dart';
import 'package:ecg_ble_app/widgets/median_beat_chart.dart';
import 'package:ecg_ble_app/widgets/recording_stats_card.dart';

const int fs = 250;   // 1 sample = 4 ms

// beat positions (in samples) from a list of intervals in ms, the first beat at 1 s
List<int> beatsFrom(List<int> intervalsMs) {
  List<int> beats = [fs];
  for (int ms in intervalsMs) {
    beats.add(beats.last + ms ~/ 4);
  }
  return beats;
}

void main() {
  test('heart rate class: < 60 slow, 60-100 normal, > 100 fast', () {
    expect(RhythmAnalysis.classify(59), HeartRateClass.slow);
    expect(RhythmAnalysis.classify(60), HeartRateClass.normal);
    expect(RhythmAnalysis.classify(100), HeartRateClass.normal);
    expect(RhythmAnalysis.classify(101), HeartRateClass.fast);
  });

  test('a steady rhythm with normal breathing changes (+-10 %): no premature beats', () {
    List<int> beats = beatsFrom([for (int k = 0; k < 40; k++) 800 + (k % 6 - 3) * 25]);
    expect(RhythmAnalysis.findPremature(beats, fs), isEmpty);
  });

  test('an extra beat 500 ms early with a compensatory pause (1100 ms) is found', () {
    // 12 normal intervals, then the extra beat after 500 ms, the pause, normal again
    List<int> beats = beatsFrom([...List.filled(12, 800), 500, 1100, ...List.filled(5, 800)]);
    expect(RhythmAnalysis.findPremature(beats, fs), [beats[13]]);
  });

  test('an early beat without the full pause (atrial: the next interval ~ normal) is found', () {
    List<int> beats = beatsFrom([...List.filled(12, 800), 560, 780, ...List.filled(5, 800)]);
    expect(RhythmAnalysis.findPremature(beats, fs), [beats[13]]);
  });

  test('every second beat early (bigeminy): all of them are found', () {
    List<int> beats = beatsFrom([...List.filled(10, 800), for (int k = 0; k < 6; k++) ...[520, 1080], 800]);
    expect(RhythmAnalysis.findPremature(beats, fs).length, 6);
  });

  test('a false detection in the middle of an interval (e.g. a tall T wave) is not a premature beat', () {
    // 800 ms split into 300 + 500: the interval after it is short too, no pause
    List<int> beats = beatsFrom([...List.filled(12, 800), 300, 500, ...List.filled(5, 800)]);
    expect(RhythmAnalysis.findPremature(beats, fs), isEmpty);
  });

  test('a missed beat or a lost packet (a long gap) is not a premature beat', () {
    List<int> beats = beatsFrom([...List.filled(12, 800), 1600, 3000, ...List.filled(12, 800)]);
    expect(RhythmAnalysis.findPremature(beats, fs), isEmpty);
  });

  test('an early beat inside an artifact (cough, movement) is not judged', () {
    List<int> beats = beatsFrom([...List.filled(12, 800), 500, 1100, ...List.filled(5, 800)]);
    int extra = beats[13];
    expect(RhythmAnalysis.findPremature(beats, fs, disturbed: (s) => (s - extra).abs() < fs), isEmpty);
  });

  test('the first beats have no reference yet, a too short recording gives nothing', () {
    expect(RhythmAnalysis.findPremature(beatsFrom([800, 800, 500, 1100, 800]), fs), isEmpty);
    expect(RhythmAnalysis.findPremature([], fs), isEmpty);
  });

  test('analyze: the class from the average and the premature beats together', () {
    List<int> beats = beatsFrom([...List.filled(12, 1100), 700, 1500, ...List.filled(5, 1100)]);
    RhythmAnalysis r = RhythmAnalysis.analyze(beats, fs, 55);
    expect(r.rateClass, HeartRateClass.slow);
    expect(r.prematureBeats, [beats[13]]);
  });

  test('the texts: the rate class and the Polish plural of the premature beats', () {
    AppLocalizations pl = lookupAppLocalizations(const Locale('pl'));
    List<String> lines(List<int> intervals, int bpm) =>
        RecordingStatsCard.rhythmLines(pl, RhythmAnalysis.analyze(beatsFrom(intervals), fs, bpm));
    List<int> one = [...List.filled(12, 800), 500, 1100, ...List.filled(5, 800)];
    List<int> two = [...one, ...List.filled(8, 800), 500, 1100, 800];
    List<int> five = [...List.filled(10, 800), for (int k = 0; k < 5; k++) ...[520, 1080], 800];
    expect(lines(List.filled(20, 800), 75),
        ['Tętno w normie (60–100 bpm).', 'Nie znaleziono pobudzeń przedwczesnych.', 'Brak pauz 2 s lub dłuższych.']);
    expect(lines(one, 52)[0], startsWith('Wolne tętno'));
    expect(lines(one, 120)[0], startsWith('Szybkie tętno'));
    expect(lines(one, 75)[1], startsWith('1 pobudzenie przedwczesne'));
    expect(lines(two, 75)[1], startsWith('2 pobudzenia przedwczesne'));
    expect(lines(five, 75)[1], startsWith('5 pobudzeń przedwczesnych'));
    AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    expect(en.rhythmPremature(3), startsWith('3 premature beats'));
  });

  test('the irregular rhythm line, and the premature beats inside it are left out', () {
    AppLocalizations pl = lookupAppLocalizations(const Locale('pl'));
    Random random = Random(2);
    // 1 min of a normal rhythm with one premature beat, then 1.5 min of random intervals
    List<int> intervals = [...List.filled(12, 800), 500, 1100, ...List.filled(60, 800),
        for (int k = 0; k < 120; k++) 450 + random.nextInt(600)];
    List<int> beats = beatsFrom(intervals);
    RhythmAnalysis rhythm = RhythmAnalysis.analyze(beats, fs, 75);
    AfDetector af = AfDetector.analyze(beats, fs);
    expect(af.suspected, isTrue);
    RhythmAnalysis outside = rhythm.without(af.contains);
    expect(outside.prematureBeats, [beats[13]]);   // only the one in the normal rhythm is left
    expect(rhythm.prematureBeats.length, greaterThan(1));
    List<String> lines = RecordingStatsCard.rhythmLines(pl, outside, af: af);
    expect(lines[1], startsWith('Nieregularny rytm przez '));   // right after the heart rate
    expect(lines[1], contains('migotanie przedsionków'));

    AfDetector none = AfDetector.analyze(beatsFrom(List.filled(100, 800)), fs);
    expect(RecordingStatsCard.rhythmLines(pl, rhythm, af: none)[1], startsWith('Brak nieregularnego rytmu'));
  });

  testWidgets('the statistics card shows the rhythm part only when it is given', (tester) async {
    List<int> beats = beatsFrom([...List.filled(12, 800), 500, 1100, ...List.filled(5, 800)]);
    RrStats stats = RrStats.fromBeats(beats, fs)!;
    Widget app(Widget child) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('pl'),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        );
    await tester.pumpWidget(app(RecordingStatsCard(stats: stats, durationSeconds: 20,
        rhythm: RhythmAnalysis.analyze(beats, fs, stats.averageBpm))));
    expect(find.text('Rytm'), findsOneWidget);
    expect(find.textContaining('1 pobudzenie przedwczesne'), findsOneWidget);
    expect(find.text('To nie jest diagnoza medyczna.'), findsOneWidget);
    expect(find.text('•  '), findsWidgets);   // the findings as a list

    await tester.pumpWidget(app(RecordingStatsCard(stats: stats, durationSeconds: 20)));
    expect(find.text('Rytm'), findsNothing);

    // with the signal: the QRS width, the ventricular beats and the median beat chart
    List<double> x = [
      for (int i = 0; i <= beats.last + 100; i++)
        beats.any((b) => (i - b).abs() < 10) ? 1 - (i - beats.firstWhere((b) => (i - b).abs() < 10)).abs() / 10 : 0,
    ];
    RhythmAnalysis rhythm = RhythmAnalysis.analyze(beats, fs, stats.averageBpm, signal: x);
    await tester.pumpWidget(app(RecordingStatsCard(stats: stats, durationSeconds: 20, rhythm: rhythm)));
    expect(find.textContaining('Typowa szerokość QRS:'), findsOneWidget);
    expect(find.textContaining('Żadne o innym kształcie'), findsOneWidget);
    expect(find.byType(MedianBeatChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ---- the beat shape, pairs / runs, pauses (a signal with beats of two shapes)

  // a QRS at every beat: a narrow up-down one (normal) or a wide down-up one (ventricular)
  List<double> signalFor(List<int> beats, Set<int> ventricular) {
    List<double> x = List.filled(beats.last + fs, 0);
    for (int b in beats) {
      bool v = ventricular.contains(b);
      int half = v ? 18 : 6;   // 4 ms samples: ~150 ms or ~50 ms
      for (int i = -half; i <= half; i++) {
        double shape = 1 - i.abs() / half;
        x[b + i] += v ? (i < 0 ? -1.2 : 0.8) * shape : shape;
      }
    }
    return x;
  }

  test('the shape rule: a ventricular beat only a bit early, without a pause, is found', () {
    // 760 ms instead of 800 (95 %) and no pause after it: the timing rule misses it
    List<int> beats = beatsFrom([...List.filled(12, 800), 740, 860, ...List.filled(8, 800)]);
    Set<int> v = {beats[13]};
    RhythmAnalysis timingOnly = RhythmAnalysis.analyze(beats, fs, 75);
    expect(timingOnly.prematureBeats, isEmpty);
    RhythmAnalysis r = RhythmAnalysis.analyze(beats, fs, 75, signal: signalFor(beats, v));
    expect(r.prematureBeats, [beats[13]]);
    expect(r.ventricular, {beats[13]});
    expect(r.qrs?.medianBeat, isNotNull);
  });

  test('a beat of the usual shape that is early by timing is not ventricular', () {
    List<int> beats = beatsFrom([...List.filled(12, 800), 500, 1100, ...List.filled(8, 800)]);
    RhythmAnalysis r = RhythmAnalysis.analyze(beats, fs, 75, signal: signalFor(beats, {}));
    expect(r.prematureBeats, [beats[13]]);
    expect(r.ventricular, isEmpty);
  });

  test('ventricular beats in a row: a pair and a run of 3', () {
    List<int> beats = beatsFrom([...List.filled(12, 800), 500, 500, 1300, ...List.filled(10, 800),
        500, 500, 500, 1300, ...List.filled(5, 800)]);
    Set<int> v = {beats[13], beats[14], beats[26], beats[27], beats[28]};
    RhythmAnalysis r = RhythmAnalysis.analyze(beats, fs, 75, signal: signalFor(beats, v));
    expect(r.ventricular, v);
    expect(r.runs, [[beats[13], beats[14]], [beats[26], beats[27], beats[28]]]);
    expect((r.pairs, r.longRuns), (1, 1));
    // without(): a run with a left out beat is gone
    expect(r.without((s) => s == beats[27]).runs, [[beats[13], beats[14]]]);
  });

  test('pauses: 2 s or longer, not over a lost packet or an artifact', () {
    List<int> beats = beatsFrom([...List.filled(10, 800), 2400, ...List.filled(5, 800), 1900,
        ...List.filled(5, 800), 2600, ...List.filled(5, 800), 3000, 800]);
    List<(int, int)> all = RhythmAnalysis.findPauses(beats, fs);
    expect(all, [(beats[10], beats[11]), (beats[22], beats[23]), (beats[28], beats[29])]);   // not the 1.9 s one
    // a lost packet inside the 2nd one, an artifact inside the 3rd one
    int gapAt = beats[22] + 100, artifactAt = beats[28] + 300;
    List<(int, int)> real = RhythmAnalysis.findPauses(beats, fs,
        gaps: [(gapAt, gapAt + 20)], disturbed: (s) => (s - artifactAt).abs() < 50);
    expect(real, [(beats[10], beats[11])]);
    AppLocalizations pl = lookupAppLocalizations(const Locale('pl'));
    RhythmAnalysis r = RhythmAnalysis.analyze(beats, fs, 70);
    expect(RecordingStatsCard.rhythmLines(pl, r).last, 'Pauzy 2 s lub dłuższe: 3, najdłuższa 3,0 s.');
  });

  test('a beat the detector missed (it is in the signal) is not a pause', () {
    // 55 bpm, every interval 1100 ms; the detector "missed" beat 15: 2200 ms without a beat
    List<int> all = beatsFrom(List.filled(25, 1100));
    List<double> x = signalFor(all, {});
    List<int> found = [...all.take(15), ...all.skip(16)];
    expect(RhythmAnalysis.analyze(found, fs, 55).pauses.length, 1);          // only the timing: a pause
    expect(RhythmAnalysis.analyze(found, fs, 55, signal: x).pauses, isEmpty);   // the beat is there
    // a real pause: nothing in the signal either
    List<double> quiet = signalFor(found, {});
    expect(RhythmAnalysis.analyze(found, fs, 55, signal: quiet).pauses, [(all[14], all[16])]);
  });

  test('a finding as a sentence: a capital letter and one full stop', () {
    expect(RecordingStatsCard.sentence('w tym 2 o innym kształcie'), 'W tym 2 o innym kształcie.');
    expect(RecordingStatsCard.sentence('Tętno w normie (60–100 bpm)'), 'Tętno w normie (60–100 bpm).');
    expect(RecordingStatsCard.sentence('Już ze zdaniem.'), 'Już ze zdaniem.');
    expect(RecordingStatsCard.sentence(''), '');
  });
}

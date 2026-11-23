import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:ecg_ble_app/l10n/app_localizations.dart';
import 'package:ecg_ble_app/qrs_width.dart';
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
    expect(lines(List.filled(20, 800), 75), ['Tętno w normie (60–100 bpm)', 'Nie znaleziono pobudzeń przedwczesnych']);
    expect(lines(one, 52)[0], startsWith('Wolne tętno'));
    expect(lines(one, 120)[0], startsWith('Szybkie tętno'));
    expect(lines(one, 75)[1], startsWith('1 pobudzenie przedwczesne'));
    expect(lines(two, 75)[1], startsWith('2 pobudzenia przedwczesne'));
    expect(lines(five, 75)[1], startsWith('5 pobudzeń przedwczesnych'));
    AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    expect(en.rhythmPremature(3), startsWith('3 premature beats'));
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
    expect(find.textContaining('nie diagnoza'), findsOneWidget);

    await tester.pumpWidget(app(RecordingStatsCard(stats: stats, durationSeconds: 20)));
    expect(find.text('Rytm'), findsNothing);

    // with the QRS: its width, the wide premature beats and the median beat chart
    List<double> x = [
      for (int i = 0; i <= beats.last + 100; i++)
        beats.any((b) => (i - b).abs() < 10) ? 1 - (i - beats.firstWhere((b) => (i - b).abs() < 10)).abs() / 10 : 0,
    ];
    RhythmAnalysis rhythm = RhythmAnalysis.analyze(beats, fs, stats.averageBpm);
    QrsSummary qrs = QrsSummary.analyze(x, beats, fs, premature: rhythm.prematureBeats);
    await tester.pumpWidget(app(RecordingStatsCard(stats: stats, durationSeconds: 20, rhythm: rhythm, qrs: qrs)));
    expect(find.textContaining('Typowa szerokość QRS:'), findsOneWidget);
    expect(find.textContaining('żadne z szerokim QRS'), findsOneWidget);
    expect(find.byType(MedianBeatChart), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

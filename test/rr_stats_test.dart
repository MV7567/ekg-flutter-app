import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/heart_rate_detector.dart';
import 'package:ecg_ble_app/l10n/app_localizations.dart';
import 'package:ecg_ble_app/rr_stats.dart';
import 'package:ecg_ble_app/widgets/recording_stats_card.dart';
import 'package:ecg_ble_app/widgets/rr_tachogram.dart';

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
  test('a perfectly steady 75 bpm: no variability', () {
    RrStats s = RrStats.fromBeats(beatsFrom(List.filled(20, 800)), fs)!;
    expect((s.minBpm, s.averageBpm, s.maxBpm), (75, 75, 75));
    expect(s.sdnnMs, 0);
    expect(s.rmssdMs, 0);
    expect(s.excludedIntervals, 0);
    expect(s.beatCount, 21);
    expect(s.tachogram.length, 20);
  });

  test('alternating 760 / 840 ms: RMSSD = 80 ms, SDNN ~ 40 ms (worked out by hand)', () {
    RrStats s = RrStats.fromBeats(beatsFrom([for (int k = 0; k < 20; k++) k.isEven ? 760 : 840]), fs)!;
    expect(s.rmssdMs, closeTo(80, 0.001));        // every neighbour difference is 80 ms
    expect(s.sdnnMs, closeTo(41.04, 0.01));       // 40 * sqrt(20 / 19), n - 1 in the formula
    expect(s.averageBpm, 75);                     // mean 800 ms
    expect(s.minBpm, 71);                         // 60000 / 840
    expect(s.maxBpm, 79);                         // 60000 / 760
  });

  test('a missed beat (one double interval) is left out and does not create variability', () {
    List<int> intervals = List.filled(20, 800);
    intervals[10] = 1600;   // the detector missed one beat
    RrStats s = RrStats.fromBeats(beatsFrom(intervals), fs)!;
    expect(s.excludedIntervals, 1);
    expect(s.sdnnMs, 0);
    expect(s.rmssdMs, 0);   // no difference across the gap
    expect(s.minBpm, 75);   // not 38 bpm
  });

  test('an artifact counted as a beat (800 -> 300 + 500) is left out', () {
    List<int> intervals = List.filled(20, 800, growable: true);   // growable: replaceRange makes it longer
    intervals.replaceRange(10, 11, [300, 500]);
    RrStats s = RrStats.fromBeats(beatsFrom(intervals), fs)!;
    expect(s.excludedIntervals, 2);
    expect(s.maxBpm, 75);   // not 200 bpm
    expect(s.sdnnMs, 0);
  });

  test('the average is the same as the one next to the chart (HeartRateDetector.averageBpm)', () {
    List<int> intervals = [for (int k = 0; k < 40; k++) 700 + (k * 37) % 160];   // 700-860 ms
    List<int> beats = beatsFrom(intervals);
    expect(RrStats.fromBeats(beats, fs)!.averageBpm, HeartRateDetector.averageBpm(beats, fs));
  });

  test('too few beats: null', () {
    expect(RrStats.fromBeats([], fs), isNull);
    expect(RrStats.fromBeats([100], fs), isNull);
    expect(RrStats.fromBeats(beatsFrom([800, 800]), fs), isNull);   // only 2 intervals
    expect(RrStats.fromBeats(beatsFrom([800, 800, 800]), fs), isNotNull);
  });

  test('tachogram range: rounded to 50 ms, at least 200 ms high', () {
    expect(RrTachogram.range([const RrPoint(1, 790), const RrPoint(2, 810)]), (700.0, 900.0));
    expect(RrTachogram.range([const RrPoint(1, 610), const RrPoint(2, 1040)]), (600.0, 1050.0));
  });

  Widget app(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('pl'),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  testWidgets('the card shows the values', (tester) async {
    RrStats stats = RrStats.fromBeats(beatsFrom([for (int k = 0; k < 20; k++) k.isEven ? 760 : 840]), fs)!;
    await tester.pumpWidget(app(RecordingStatsCard(stats: stats, durationSeconds: 20)));
    expect(find.text('Statystyki nagrania'), findsOneWidget);
    expect(find.text('SDNN'), findsOneWidget);
    expect(find.text('RMSSD'), findsOneWidget);
    expect(find.text('Uderzenia: 21, pominięte odstępy: 0 (zgubione uderzenia, artefakty)'), findsOneWidget);
    expect(find.byType(RrTachogram), findsOneWidget);
  });

  testWidgets('the card without enough beats: only a message', (tester) async {
    await tester.pumpWidget(app(const RecordingStatsCard(stats: null, durationSeconds: 3)));
    expect(find.text('Za mało uderzeń serca do statystyk.'), findsOneWidget);
    expect(find.byType(RrTachogram), findsNothing);
  });
}

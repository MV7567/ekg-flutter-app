import 'dart:math';   // max
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../af_detector.dart';
import '../ekg_config.dart';   // sampleRateHz
import '../qrs_width.dart';
import '../qt_interval.dart';
import '../rhythm_analysis.dart';
import '../rr_stats.dart';
import 'median_beat_chart.dart';
import 'rr_tachogram.dart';

// the statistics of a whole recording under its chart:
// heart rate min / average / max, HRV (SDNN, RMSSD), the tachogram and the rhythm check
class RecordingStatsCard extends StatelessWidget {
  const RecordingStatsCard({super.key, required this.stats, required this.durationSeconds, this.rhythm, this.af});

  final RrStats? stats;            // null = not enough beats
  final double durationSeconds;
  final RhythmAnalysis? rhythm;    // null = not checked (not enough beats), its qrs: the median beat
  final AfDetector? af;            // the irregular rhythm (atrial fibrillation) check, null = not checked

  // the findings of the rhythm check as sentences, static and public: the PDF report shows the same texts
  // the QT lines: nothing without the zero phase signal, "not measured" with a flat T wave,
  // otherwise the values and whether the QTc (Bazett) is normal, long or short
  static List<String> qtLines(AppLocalizations t, QtSummary? summary) {
    if (summary == null) return [];
    if (summary.variableShape) return [t.qtVariableShape];
    QtMeasurement? qt = summary.qt;
    if (qt == null) return [t.qtNotMeasured];
    return [
      t.qtValues(qt.qtMs.round(), qt.bazettMs.round(), qt.fridericiaMs.round()),
      qt.bazettMs > QtInterval.longAboveMs
          ? t.qtLong
          : qt.bazettMs < QtInterval.shortBelowMs
              ? t.qtShort
              : t.qtNormal,
    ];
  }

  // the median beat to show: the long one with the T wave (and the QT) if there is one,
  // otherwise the short one of the QRS; (beat, QRS, T end), null = none
  static (List<double>, (int, int)?, int?)? beatToShow(RhythmAnalysis rhythm) {
    // beats of different shapes: their median is no real beat, better none than a misleading one
    if (rhythm.qrs?.variableShape ?? false) return null;
    QtSummary? qt = rhythm.qt;
    if (qt != null) return (qt.beat, qt.qrs, qt.qt?.tEnd);
    List<double>? short = rhythm.qrs?.medianBeat;
    return short == null ? null : (short, rhythm.qrs!.qrs, null);
  }

  // one finding as a sentence: a capital letter at the start and a full stop at the end
  // (the texts are written as short phrases, "w tym 2 ..." is shown as its own point too)
  static String sentence(String text) {
    if (text.isEmpty) return text;
    String first = text[0].toUpperCase() + text.substring(1);
    return RegExp(r'[.!?]$').hasMatch(first) ? first : '$first.';
  }

  // with the signal (rhythm.qrs): the QRS width and how many premature beats were ventricular
  // af: adds the irregular rhythm line
  static List<String> rhythmLines(AppLocalizations t, RhythmAnalysis rhythm, {AfDetector? af}) {
    QrsSummary? qrs = rhythm.qrs;
    double? ms = qrs?.typicalMs(sampleRateHz);
    double longestPause = rhythm.pauses.fold(0.0, (m, p) => max(m, (p.$2 - p.$1) / sampleRateHz));
    return [
      for (String line in [
        switch (rhythm.rateClass) {
          HeartRateClass.slow => t.rhythmSlow,
          HeartRateClass.normal => t.rhythmNormal,
          HeartRateClass.fast => t.rhythmFast,
        },
        if (af != null) af.suspected ? t.afSuspected(af.seconds(sampleRateHz).round()) : t.afNone,
        t.rhythmPremature(rhythm.prematureBeats.length),
        if (qrs != null && rhythm.prematureBeats.isNotEmpty) t.rhythmPrematureWide(rhythm.ventricular.length),
        if (rhythm.runs.isNotEmpty) t.rhythmRuns(rhythm.pairs, rhythm.longRuns),
        rhythm.pauses.isEmpty ? t.rhythmNoPauses : t.rhythmPauses(rhythm.pauses.length, longestPause),
        if (qrs != null)
          if (qrs.variableShape)
            t.qrsVariableShape
          else if (ms == null)
            t.qrsNotMeasured
          else if (ms >= QrsWidth.wideMs)
            t.qrsTypicalWide(ms.round())
          else
            t.qrsTypical(ms.round()),
        ...qtLines(t, rhythm.qt),
      ])
        sentence(line),
    ];
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations t = AppLocalizations.of(context);
    TextTheme text = Theme.of(context).textTheme;
    RrStats? s = stats;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.statsTitle, style: text.titleMedium),
            const SizedBox(height: 12),
            if (s == null)
              Text(t.statsNotEnoughBeats)
            else ...[
              // three values side by side, like on a sports watch
              Row(
                children: [
                  _value(context, t.statsMin, '${s.minBpm}', 'bpm'),
                  _value(context, t.statsAverage, '${s.averageBpm}', 'bpm'),
                  _value(context, t.statsMax, '${s.maxBpm}', 'bpm'),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _value(context, 'SDNN', s.sdnnMs.toStringAsFixed(0), 'ms'),
                  _value(context, 'RMSSD', s.rmssdMs?.toStringAsFixed(0) ?? '--', 'ms'),
                  const Expanded(child: SizedBox()),   // the same column width as above
                ],
              ),
              const SizedBox(height: 8),
              Text(t.statsBeats(s.beatCount, s.excludedIntervals), style: text.bodySmall),
              const SizedBox(height: 16),
              Text(t.statsTachogram, style: text.bodyMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                width: double.infinity,
                child: RrTachogram(points: s.tachogram, durationSeconds: durationSeconds),
              ),
              const SizedBox(height: 8),
              Text(t.statsHrvHint, style: text.bodySmall),
              if (rhythm != null) ...[
                const SizedBox(height: 16),
                Text(t.rhythmTitle, style: text.titleMedium),
                const SizedBox(height: 8),
                // not a diagnosis: first and clearly visible, in a red frame
                _warning(context, t),
                const SizedBox(height: 12),
                // every finding as a point of a list
                for (String line in rhythmLines(t, rhythm!, af: af))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(child: Text(line)),
                      ],
                    ),
                  ),
                // the median beat with the measured QRS, so the measurement can be checked by eye
                if (beatToShow(rhythm!) case (List<double> beat, (int, int)? q, int? tEnd)) ...[
                  const SizedBox(height: 12),
                  Text(t.qrsMedianBeat(rhythm!.qrs?.beatCount ?? 0), style: text.bodyMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: MedianBeatChart(beat: beat, qrs: q, tEnd: tEnd, sampleRateHz: sampleRateHz),
                  ),
                  const SizedBox(height: 8),   // the chart is the last thing in the card
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  // the red frame with "this is not a medical diagnosis" and what the check can not do
  // (the error colors of the theme: red in the light and in the dark theme)
  Widget _warning(BuildContext context, AppLocalizations t) {
    ColorScheme colors = Theme.of(context).colorScheme;
    TextTheme text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        border: Border.all(color: colors.error, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.rhythmWarning,
                    style: text.titleSmall?.copyWith(color: colors.onErrorContainer, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(t.rhythmHint, style: text.bodySmall?.copyWith(color: colors.onErrorContainer)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // a small label above a big number with its unit
  Widget _value(BuildContext context, String label, String value, String unit) {
    TextTheme text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.bodySmall),
          Text.rich(TextSpan(children: [
            TextSpan(text: value, style: text.headlineSmall),
            TextSpan(text: ' $unit', style: text.bodySmall),
          ])),
        ],
      ),
    );
  }
}

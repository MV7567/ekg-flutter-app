import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../ekg_config.dart';   // sampleRateHz
import '../qrs_width.dart';
import '../rhythm_analysis.dart';
import '../rr_stats.dart';
import 'median_beat_chart.dart';
import 'rr_tachogram.dart';

// the statistics of a whole recording under its chart:
// heart rate min / average / max, HRV (SDNN, RMSSD), the tachogram and the rhythm check
class RecordingStatsCard extends StatelessWidget {
  const RecordingStatsCard({super.key, required this.stats, required this.durationSeconds, this.rhythm, this.qrs});

  final RrStats? stats;            // null = not enough beats
  final double durationSeconds;
  final RhythmAnalysis? rhythm;    // null = not checked (not enough beats)
  final QrsSummary? qrs;           // the QRS width and the median beat, null = not checked

  // the two lines of the rhythm check, static and public: the PDF report shows the same texts
  // qrs: adds the QRS width and how many of the premature beats were wide
  static List<String> rhythmLines(AppLocalizations t, RhythmAnalysis rhythm, {QrsSummary? qrs}) {
    double? ms = qrs?.typicalMs(sampleRateHz);
    return [
      switch (rhythm.rateClass) {
        HeartRateClass.slow => t.rhythmSlow,
        HeartRateClass.normal => t.rhythmNormal,
        HeartRateClass.fast => t.rhythmFast,
      },
      t.rhythmPremature(rhythm.prematureBeats.length),
      if (qrs != null && rhythm.prematureBeats.isNotEmpty) t.rhythmPrematureWide(qrs.widePremature.length),
      if (qrs != null)
        if (ms == null)
          t.qrsNotMeasured
        else if (ms >= QrsWidth.wideMs)
          t.qrsTypicalWide(ms.round())
        else
          t.qrsTypical(ms.round()),
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
                for (String line in rhythmLines(t, rhythm!, qrs: qrs)) Text(line),
                // the median beat with the measured QRS, so the measurement can be checked by eye
                if (qrs?.medianBeat != null) ...[
                  const SizedBox(height: 12),
                  Text(t.qrsMedianBeat(qrs!.beatCount), style: text.bodyMedium),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: MedianBeatChart(beat: qrs!.medianBeat!, qrs: qrs!.qrs, sampleRateHz: sampleRateHz),
                  ),
                ],
                const SizedBox(height: 8),
                Text(t.rhythmHint, style: text.bodySmall),
              ],
            ],
          ],
        ),
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

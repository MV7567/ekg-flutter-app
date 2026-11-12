import 'package:flutter/material.dart';
import '../ekg_auto_scale.dart';
import '../l10n/app_localizations.dart';
import 'ekg_chart.dart';

// the zoom buttons under a chart: Auto ×1 ×2 ×4 ×8
// one widget for the live screen and the recording screen, so both always have the same steps
// value = mV per big square, EkgChart.autoZoom = Auto
class ZoomSelector extends StatelessWidget {
  const ZoomSelector({super.key, required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  // every option in order: Auto first, then ×1 .. ×8
  static const List<double> options = [EkgChart.autoZoom, ...EkgAutoScale.steps];

  // "Auto", "×1", "×2", "×4", "×8"
  static String label(double mvPerBigSquare, AppLocalizations t) => mvPerBigSquare == EkgChart.autoZoom
      ? t.chartZoomAuto
      : '×${(0.5 / mvPerBigSquare).round()}';   // 0.5 mV = standard paper = ×1

  // the next one for the single zoom button in full screen: Auto -> ×1 -> ... -> ×8 -> Auto
  static double next(double mvPerBigSquare) {
    int i = options.indexOf(mvPerBigSquare);
    return options[(i + 1) % options.length];   // unknown value (-1) -> the first one
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations t = AppLocalizations.of(context);
    return SegmentedButton<double>(
      segments: [
        for (double option in options) ButtonSegment(value: option, label: Text(label(option, t))),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

import 'package:flutter/foundation.dart';   // ValueListenable
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

// "♥ 72 bpm", or "♥ -- bpm" while the heart rate is not known yet
// listens to the ValueNotifier itself: only this small widget redraws when the number changes,
// not the whole screen
class HeartRateText extends StatelessWidget {
  const HeartRateText({super.key, required this.bpm, this.fontSize = 24, this.color});

  final ValueListenable<int?> bpm;
  final double fontSize;
  final Color? color;   // null = the normal text color of the theme

  @override
  Widget build(BuildContext context) {
    AppLocalizations t = AppLocalizations.of(context);
    return ValueListenableBuilder<int?>(
      valueListenable: bpm,
      builder: (context, value, _) => Row(
        mainAxisSize: MainAxisSize.min,   // only as wide as the content, so it can be centered
        children: [
          Icon(Icons.favorite, color: Colors.red, size: fontSize),
          const SizedBox(width: 6),
          Text(
            t.heartRate(value?.toString() ?? '--'),
            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

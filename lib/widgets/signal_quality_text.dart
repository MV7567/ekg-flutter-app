import 'package:flutter/foundation.dart';   // ValueListenable
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../signal_quality.dart';

// a colored icon + what to do, e.g. "✔ Good signal" or "⚠ Noisy signal – sit still..."
// green = ok, orange = works but not well, red = no usable signal
class SignalQualityText extends StatelessWidget {
  const SignalQualityText({super.key, required this.quality});

  final ValueListenable<SignalQuality> quality;

  // icon and color for every state, public for the tests
  static (IconData, Color) look(SignalQuality quality) => switch (quality) {
        SignalQuality.checking => (Icons.hourglass_empty, Colors.grey),
        SignalQuality.good => (Icons.check_circle, Colors.green),
        SignalQuality.noisy || SignalQuality.noBeats => (Icons.warning_amber, Colors.orange),
        SignalQuality.flat || SignalQuality.electrodeOff => (Icons.error, Colors.red),
      };

  static String text(AppLocalizations t, SignalQuality quality) => switch (quality) {
        SignalQuality.checking => t.qualityChecking,
        SignalQuality.good => t.qualityGood,
        SignalQuality.noisy => t.qualityNoisy,
        SignalQuality.noBeats => t.qualityNoBeats,
        SignalQuality.flat => t.qualityFlat,
        SignalQuality.electrodeOff => t.qualityElectrodeOff,
      };

  @override
  Widget build(BuildContext context) {
    AppLocalizations t = AppLocalizations.of(context);
    return ValueListenableBuilder<SignalQuality>(
      valueListenable: quality,
      builder: (context, value, _) {
        var (icon, color) = look(value);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            // Flexible: a long warning goes to a second line instead of overflowing
            Flexible(child: Text(text(t, value), textAlign: TextAlign.center)),
          ],
        );
      },
    );
  }
}

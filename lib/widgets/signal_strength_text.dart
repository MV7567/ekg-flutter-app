import 'package:flutter/foundation.dart';   // ValueListenable
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

// how strong the BLE radio signal from the ESP32 is
enum SignalStrength { strong, fair, weak }

// "BLE signal: -62 dBm (strong)" with signal bars, shown while connected
// RSSI = Received Signal Strength Indicator, in dBm, always negative: closer to 0 = stronger
// a weak signal = lost packets = gaps in the recording, so it tells you to move the phone closer
class SignalStrengthText extends StatelessWidget {
  const SignalStrengthText({super.key, required this.rssi});

  final ValueListenable<int?> rssi;   // null = not read yet, nothing is shown

  // usual BLE limits: above -70 dBm everything arrives, under -85 dBm packets start to get lost
  static SignalStrength strength(int rssi) {
    if (rssi >= -70) return SignalStrength.strong;
    if (rssi >= -85) return SignalStrength.fair;
    return SignalStrength.weak;
  }

  // icon and color for every strength, public for the tests
  static (IconData, Color) look(SignalStrength strength) => switch (strength) {
        SignalStrength.strong => (Icons.signal_cellular_alt, Colors.green),
        SignalStrength.fair => (Icons.signal_cellular_alt_2_bar, Colors.orange),
        SignalStrength.weak => (Icons.signal_cellular_alt_1_bar, Colors.red),
      };

  static String levelText(AppLocalizations t, SignalStrength strength) => switch (strength) {
        SignalStrength.strong => t.signalStrong,
        SignalStrength.fair => t.signalFair,
        SignalStrength.weak => t.signalWeak,
      };

  @override
  Widget build(BuildContext context) {
    AppLocalizations t = AppLocalizations.of(context);
    return ValueListenableBuilder<int?>(
      valueListenable: rssi,
      builder: (context, value, _) {
        if (value == null) return const SizedBox.shrink();   // nothing read yet
        SignalStrength s = strength(value);
        var (icon, color) = look(s);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Flexible(child: Text(t.deviceSignalStrength(value, levelText(t, s)), textAlign: TextAlign.center)),
          ],
        );
      },
    );
  }
}

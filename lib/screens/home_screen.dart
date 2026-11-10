import 'package:flutter/foundation.dart';   // kDebugMode
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'device_screen.dart';
import 'instructions_screen.dart';
import 'recordings_screen.dart';
import 'scanner_screen.dart';
import 'settings_screen.dart';

// first screen of the app: the name and big buttons to the main parts
// stateless: it only shows buttons, every part has its own screen with its own state
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    ColorScheme colors = Theme.of(context).colorScheme;   // colors of the current theme (light / dark)
    AppLocalizations t = AppLocalizations.of(context);   // texts in the language chosen in Settings

    return Scaffold(
      // no AppBar: the name is in the middle, a start screen does not need a back arrow
      body: SafeArea(
        child: Center(
          // scrolls in landscape if the buttons do not fit
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              // on a wide screen (landscape, tablet) the buttons do not stretch across everything
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                // buttons as wide as the column
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.monitor_heart, size: 96, color: colors.primary),
                  const SizedBox(height: 12),
                  Text(t.appTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall),
                  Text(t.homeSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceVariant)),
                  const SizedBox(height: 48),

                  // the main action is filled, the others outlined: the eye goes to it first
                  _bigButton(
                    filled: true,
                    icon: Icons.bluetooth_searching,
                    label: t.homeConnect,
                    onPressed: () => _open(context, const ScannerScreen()),
                  ),
                  const SizedBox(height: 12),
                  _bigButton(
                    icon: Icons.folder_open,
                    label: t.homeRecordings,
                    onPressed: () => _open(context, const RecordingsScreen()),
                  ),
                  const SizedBox(height: 12),
                  _bigButton(
                    icon: Icons.help_outline,
                    label: t.homeHowToMeasure,
                    onPressed: () => _open(context, const InstructionsScreen()),
                  ),
                  const SizedBox(height: 12),
                  _bigButton(
                    icon: Icons.settings,
                    label: t.homeSettings,
                    onPressed: () => _open(context, const SettingsScreen()),
                  ),

                  // debug builds only, like the 🧪 in the scanner
                  if (kDebugMode) ...[
                    const SizedBox(height: 24),
                    TextButton.icon(
                      icon: const Icon(Icons.science),
                      label: Text(t.homeTestSignal),
                      onPressed: () => _open(context, const DeviceScreen.testSignal()),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => screen));
  }

  // one look for all the big buttons, filled = the main one
  Widget _bigButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool filled = false,
  }) {
    ButtonStyle style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(56)),   // taller, easy to hit
      textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 18)),
    );
    return filled
        ? FilledButton.icon(style: style, onPressed: onPressed, icon: Icon(icon), label: Text(label))
        : OutlinedButton.icon(style: style, onPressed: onPressed, icon: Icon(icon), label: Text(label));
  }
}

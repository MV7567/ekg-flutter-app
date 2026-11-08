import 'package:flutter/material.dart';
import '../settings/app_settings.dart';

// settings, for now only the theme, more sections can be added below
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppSettings settings = AppSettings.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      // ListenableBuilder redraws only this part when the settings change
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          children: [
            const ListTile(
              title: Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            // RadioGroup holds the chosen value, the RadioListTiles inside only say their own value
            RadioGroup<ThemeMode>(
              groupValue: settings.themeMode,
              onChanged: (mode) {
                if (mode != null) settings.setThemeMode(mode);
              },
              child: const Column(
                children: [
                  RadioListTile(
                    value: ThemeMode.system,
                    title: Text('System'),
                    subtitle: Text('Like the phone'),
                  ),
                  RadioListTile(value: ThemeMode.light, title: Text('Light')),
                  RadioListTile(value: ThemeMode.dark, title: Text('Dark')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

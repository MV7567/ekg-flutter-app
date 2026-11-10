import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_settings.dart';

// settings, more sections can be added below
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    AppSettings settings = AppSettings.instance;
    AppLocalizations t = AppLocalizations.of(context);   // texts in the current language

    return Scaffold(
      appBar: AppBar(title: Text(t.settingsTitle)),
      // ListenableBuilder redraws only this part when the settings change
      body: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => ListView(
          children: [
            _header(t.settingsAppearance),
            // RadioGroup holds the chosen value, the RadioListTiles inside only say their own value
            RadioGroup<ThemeMode>(
              groupValue: settings.themeMode,
              onChanged: (mode) {
                if (mode != null) settings.setThemeMode(mode);
              },
              child: Column(
                children: [
                  RadioListTile(
                    value: ThemeMode.system,
                    title: Text(t.settingsThemeSystem),
                    subtitle: Text(t.settingsLikePhone),
                  ),
                  RadioListTile(value: ThemeMode.light, title: Text(t.settingsThemeLight)),
                  RadioListTile(value: ThemeMode.dark, title: Text(t.settingsThemeDark)),
                ],
              ),
            ),

            _header(t.settingsLanguage),
            RadioGroup<String>(
              groupValue: settings.languageCode,
              onChanged: (code) {
                if (code != null) settings.setLanguageCode(code);
              },
              child: Column(
                children: [
                  RadioListTile(
                    value: '',
                    title: Text(t.settingsLanguageSystem),
                    subtitle: Text(t.settingsLikePhone),
                  ),
                  // one row per .arb file, a new language shows up here by itself
                  for (Locale locale in AppLocalizations.supportedLocales)
                    RadioListTile(
                      value: locale.languageCode,
                      // the name in its own language ("Polski", "English"), like on every phone,
                      // so someone who can't read the current language still finds their own
                      title: Text(lookupAppLocalizations(locale).languageName),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(String text) =>
      ListTile(title: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)));
}

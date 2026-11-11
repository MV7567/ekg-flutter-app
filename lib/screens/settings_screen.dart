import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../settings/app_palette.dart';
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

            _header(t.settingsColors),
            // a row of color circles, Wrap goes to the next line when they don't fit
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (AppPalette palette in AppPalette.values)
                    _PaletteCircle(
                      palette: palette,
                      label: palette.label(t),
                      selected: palette == settings.palette,
                      onTap: () => settings.setPalette(palette),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // the EKG chart: classic or in the palette colors
            SwitchListTile(
              title: Text(t.settingsChartMatchesPalette),
              subtitle: Text(t.settingsChartMatchesPaletteHint),
              value: settings.chartMatchesPalette,
              onChanged: settings.setChartMatchesPalette,
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

// one palette in Settings: a circle in its main color with its name under it,
// the chosen one has a tick and a ring around it
class _PaletteCircle extends StatelessWidget {
  const _PaletteCircle({
    required this.palette,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AppPalette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // the real main color of this palette in the current light/dark mode,
    // fromSeed changes the seed a bit, so the circle shows what the buttons will really look like
    ColorScheme colors = ColorScheme.fromSeed(seedColor: palette.seed, brightness: Theme.of(context).brightness);
    Color ring = Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: SizedBox(
          width: 72,   // the same width for every name, so the circles stay in neat columns
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.primary,
                  shape: BoxShape.circle,
                  border: selected ? Border.all(color: ring, width: 3) : null,
                ),
                // the tick in the color that is readable on this circle
                child: selected
                    ? Icon(Icons.check, color: colors.onPrimary)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

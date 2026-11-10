import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

// color palettes to choose from in Settings
// every palette is only ONE seed color, Material 3 (ColorScheme.fromSeed) makes the whole set
// from it (buttons, backgrounds, text colors), in a light and in a dark version
// a new palette = one line here + its name in the .arb files (+ a case in label)
enum AppPalette {
  red(Color(0xFFC62828)),      // the default, like the red EKG paper
  blue(Color(0xFF1E88E5)),
  teal(Color(0xFF00897B)),
  green(Color(0xFF2E7D32)),
  purple(Color(0xFF6A1B9A)),
  orange(Color(0xFFEF6C00));

  const AppPalette(this.seed);
  final Color seed;

  static const AppPalette defaultPalette = AppPalette.red;

  // the name shown in Settings, in the chosen language
  // (not "name": every enum already has .name = "red", "blue", ... used for saving)
  String label(AppLocalizations t) => switch (this) {
        AppPalette.red => t.paletteRed,
        AppPalette.blue => t.paletteBlue,
        AppPalette.teal => t.paletteTeal,
        AppPalette.green => t.paletteGreen,
        AppPalette.purple => t.palettePurple,
        AppPalette.orange => t.paletteOrange,
      };

  // "teal" -> AppPalette.teal, nothing saved or a removed palette -> the default
  static AppPalette parse(String? name) {
    for (AppPalette palette in values) {
      if (palette.name == name) return palette;
    }
    return defaultPalette;
  }
}

// the whole look of the app for one palette and light/dark,
// one place, so the light and the dark theme can't drift apart
ThemeData buildAppTheme(AppPalette palette, Brightness brightness) {
  ColorScheme colors = ColorScheme.fromSeed(seedColor: palette.seed, brightness: brightness);
  return ThemeData(
    colorScheme: colors,
    // rounder cards than the default, softer look
    cardTheme: const CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
  );
}

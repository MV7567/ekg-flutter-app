import 'package:flutter/material.dart';                         // ThemeMode, ChangeNotifier
import 'package:shared_preferences/shared_preferences.dart';    // small key-value storage on the phone
import '../l10n/app_localizations.dart';                        // the list of translated languages
import 'app_palette.dart';                                      // color palettes

// app settings, kept on the phone between launches
// one shared object (AppSettings.instance): the app (MaterialApp) listens to it,
// the settings screen changes it -> the whole app redraws with the new values
// new settings later: a field + a setter that saves it, + a line in load()
class AppSettings extends ChangeNotifier {    // extends ChangeNotifier, works like in EkgBuffer: SetThemeMode calls notifyListeners(), and everyone who is listening redraws
  AppSettings._();   // private constructor: nobody can make a second copy
  static final AppSettings instance = AppSettings._();
  // it's a singleton, bc the constructor is private noone will create a second copy of the settings
  // everyone uses AppSettings.instance: MaterialApp listens to it and the settings screen changes

  // keys in the storage, a typo here would silently lose the setting, so they are constants
  static const String _themeModeKey = 'themeMode';
  static const String _recordingSecondsKey = 'recordingSeconds';
  static const String _languageKey = 'language';
  static const String _paletteKey = 'palette';

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  ThemeMode _themeMode = ThemeMode.system;   // default: like the phone
  ThemeMode get themeMode => _themeMode;

  // colors of the app, one seed color (see app_palette.dart)
  AppPalette _palette = AppPalette.defaultPalette;
  AppPalette get palette => _palette;

  // app language as a code: "en", "pl", ..., "" = like the phone
  String _languageCode = '';
  String get languageCode => _languageCode;
  // for MaterialApp: null = choose by itself from the phone language
  Locale? get locale => _languageCode.isEmpty ? null : Locale(_languageCode);

  // length of a timed recording, the last one chosen on the device screen
  // 0 = manual (until STOP)
  static const List<int> recordingSecondsOptions = [0, 10, 30, 60, 120, 300];
  int _recordingSeconds = 0;
  int get recordingSeconds => _recordingSeconds;

  // reads the saved values, called once in main() before the app starts
  Future<void> load() async {
    try {
      _themeMode = parseThemeMode(await _prefs.getString(_themeModeKey));
      _recordingSeconds = parseRecordingSeconds(await _prefs.getInt(_recordingSecondsKey));
      _languageCode = parseLanguageCode(await _prefs.getString(_languageKey), supportedLanguageCodes);
      _palette = AppPalette.parse(await _prefs.getString(_paletteKey));
    } catch (e) {
      // storage not readable -> the defaults stay, the app still starts
      debugPrint("Settings load error: $e");
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {   // first notifyListeners then saves, then the theme changes immediately and it saves in the background, save error only in console
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();   // redraw at once, saving happens after
    try {
      await _prefs.setString(_themeModeKey, mode.name);   // saved as text: "system" / "light" / "dark"
    } catch (e) {
      debugPrint("Settings save error: $e");
    }
  }

  Future<void> setPalette(AppPalette palette) async {
    if (palette == _palette) return;
    _palette = palette;
    notifyListeners();   // MaterialApp builds the theme again, every screen changes color at once
    try {
      await _prefs.setString(_paletteKey, palette.name);   // saved as text: "red", "teal", ...
    } catch (e) {
      debugPrint("Settings save error: $e");
    }
  }

  Future<void> setRecordingSeconds(int seconds) async {
    if (seconds == _recordingSeconds) return;
    _recordingSeconds = seconds;
    notifyListeners();
    try {
      await _prefs.setInt(_recordingSecondsKey, seconds);
    } catch (e) {
      debugPrint("Settings save error: $e");
    }
  }

  Future<void> setLanguageCode(String code) async {
    if (code == _languageCode) return;
    _languageCode = code;
    notifyListeners();   // MaterialApp gets the new locale, every text changes at once
    try {
      await _prefs.setString(_languageKey, code);
    } catch (e) {
      debugPrint("Settings save error: $e");
    }
  }

  // languages that have an .arb file in lib/l10n, generated, so a new file adds a language here by itself
  static List<String> get supportedLanguageCodes =>
      AppLocalizations.supportedLocales.map((locale) => locale.languageCode).toList();

  // ---- pure functions, testable ----

  // a saved language that no longer exists (or nothing saved) -> "" = like the phone
  static String parseLanguageCode(String? code, List<String> supported) =>
      code != null && supported.contains(code) ? code : '';

  // only a value from the list, anything else (nothing saved, an old removed option) -> manual
  static int parseRecordingSeconds(int? seconds) =>
      recordingSecondsOptions.contains(seconds) ? seconds! : 0;

  // "dark" -> ThemeMode.dark, nothing saved yet or unknown text -> system
  static ThemeMode parseThemeMode(String? name) {   // changes the text back to the value, null or unknown text gives system
    for (ThemeMode mode in ThemeMode.values) {      // the themeMode key is const because a typo would lose the setting
      if (mode.name == name) return mode;
    }
    return ThemeMode.system;    // switches the theme
  }
}

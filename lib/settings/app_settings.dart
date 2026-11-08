import 'package:flutter/material.dart';                         // ThemeMode, ChangeNotifier
import 'package:shared_preferences/shared_preferences.dart';    // small key-value storage on the phone

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

  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  ThemeMode _themeMode = ThemeMode.system;   // default: like the phone
  ThemeMode get themeMode => _themeMode;

  // reads the saved values, called once in main() before the app starts
  Future<void> load() async {
    try {
      _themeMode = parseThemeMode(await _prefs.getString(_themeModeKey));
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

  // ---- pure function, testable ----

  // "dark" -> ThemeMode.dark, nothing saved yet or unknown text -> system
  static ThemeMode parseThemeMode(String? name) {   // changes the text back to the value, null or unknown text gives system
    for (ThemeMode mode in ThemeMode.values) {      // the themeMode key is const because a typo would lose the setting
      if (mode.name == name) return mode;
    }
    return ThemeMode.system;    // switches the theme
  }
}

import 'package:flutter/material.dart';   // import ui stuff
import 'screens/home_screen.dart';        // import start screen
import 'settings/app_settings.dart';      // saved settings (theme)
import 'settings/app_palette.dart';       // color palettes, buildAppTheme
import 'l10n/app_localizations.dart';     // translations, generated from lib/l10n/*.arb

// main entry point of the app
// async: the saved settings are read before the first screen, so the app does not flash light -> dark
Future<void> main() async {
  // needed before using plugins (shared_preferences) ahead of runApp
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.load();  // loads the settings before the first frame, without it the app would briefly flash the light mode
  runApp(const EkgApp());
}
// main is the first function ran by the app. runApp takes a widget and makes it the app screen
// const means the object is created once because it doesnt have any changing data, performance optimization

// main app widget, stateless because it doesn't need to update the UI
// stateless widgets dont have their own state, always looks the same for the same input
class EkgApp extends StatelessWidget {
  const EkgApp({super.key});
// super key passes an optional key to the parent class, used for widget tree optimization

  @override
  // build method to build the UI
  // build describes the look of the widget
  // @override means overriding the method from StatelessWidget, context is the spot of widget in the tree, used to get theme and localization info
  Widget build(BuildContext context) {
    // ListenableBuilder: MaterialApp is rebuilt when a setting changes (e.g. dark mode), MaterialApp is wrapped in ListenableBuilder
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) => MaterialApp(
        title: 'EKG App',
        // Material 3 ignores primarySwatch, the colors come from the colorScheme
        // the palette chosen in Settings, the theme itself is made in app_palette.dart
        theme: buildAppTheme(AppSettings.instance.palette, Brightness.light),
        // the same colors made for a dark background
        darkTheme: buildAppTheme(AppSettings.instance.palette, Brightness.dark),   // same blue but changed for the dark background
        themeMode: AppSettings.instance.themeMode,   // which one of the two is used, MaterialApp gets both motives, themeMode says which to use
        // translations: our texts (AppLocalizations) + the built-in Flutter widgets (Material, Cupertino)
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,   // from the .arb files: en, pl
        // null = the phone language if we have it, otherwise the first one (English)
        locale: AppSettings.instance.locale,
        home: const HomeScreen(),                   // the start screen, the first one the user sees
      ),
    );
    // MaterialApp is the skeleton of the app, manages navigation (Navigator), theme, language
    // title is the shown app name
    // home is the homescreen of the app
  }
}

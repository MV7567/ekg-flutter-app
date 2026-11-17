import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:ecg_ble_app/l10n/app_localizations.dart';
import 'package:ecg_ble_app/screens/home_screen.dart';
import 'package:ecg_ble_app/settings/app_settings.dart';

// the screen inside a MaterialApp with the translations, in the given language
Widget app(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: home,
    );

void main() {
  // no phone in a test: the settings are "saved" in memory instead
  SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();

  // widget test: builds the screen in memory (no phone) and looks for the texts
  testWidgets('start screen shows the main buttons', (tester) async {
    await tester.pumpWidget(app(const HomeScreen()));
    await tester.pumpAndSettle();   // translations are loaded asynchronously, wait for them

    expect(find.text('EKG'), findsOneWidget);
    expect(find.text('Connect to EKG device'), findsOneWidget);
    expect(find.text('Recordings'), findsOneWidget);
    expect(find.text('How to measure'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Test signal (debug)'), findsNothing);   // only with the advanced features
  });

  testWidgets('the test signal button follows the advanced features setting at once', (tester) async {
    addTearDown(() => AppSettings.instance.setAdvancedFeatures(false));
    await tester.pumpWidget(app(const HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Test signal (debug)'), findsNothing);

    await AppSettings.instance.setAdvancedFeatures(true);   // like the switch in Settings
    await tester.pump();
    expect(find.text('Test signal (debug)'), findsOneWidget);

    await AppSettings.instance.setAdvancedFeatures(false);
    await tester.pump();
    expect(find.text('Test signal (debug)'), findsNothing);
  });

  testWidgets('start screen in Polish', (tester) async {
    await tester.pumpWidget(app(const HomeScreen(), locale: const Locale('pl')));
    await tester.pumpAndSettle();

    expect(find.text('Połącz z urządzeniem EKG'), findsOneWidget);
    expect(find.text('Nagrania'), findsOneWidget);
    expect(find.text('Ustawienia'), findsOneWidget);
  });

  testWidgets('start screen fits in landscape without overflow', (tester) async {
    tester.view.physicalSize = const Size(2400, 1080);   // phone turned sideways
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(const HomeScreen()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);   // an overflow would be reported here
  });
}

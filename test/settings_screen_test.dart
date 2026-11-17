import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:ecg_ble_app/l10n/app_localizations.dart';
import 'package:ecg_ble_app/screens/settings_screen.dart';
import 'package:ecg_ble_app/settings/app_palette.dart';
import 'package:ecg_ble_app/settings/app_settings.dart';

void main() {
  // no phone in a test: the settings are "saved" in memory instead
  SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();

  testWidgets('every palette has a circle, tapping one chooses it', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);   // a tall phone, everything visible
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('pl'),
      home: const SettingsScreen(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Kolory'), findsOneWidget);
    for (String name in ['Czerwony', 'Niebieski', 'Turkusowy', 'Zielony', 'Fioletowy', 'Pomarańczowy']) {
      expect(find.text(name), findsOneWidget);
    }

    // the default (red) has the tick
    expect(AppSettings.instance.palette, AppPalette.red);
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.tap(find.text('Turkusowy'));
    await tester.pumpAndSettle();
    expect(AppSettings.instance.palette, AppPalette.teal);
    expect(find.byIcon(Icons.check), findsOneWidget);   // still only one tick, now on teal
  });

  testWidgets('the chart switch turns the palette colors on and off', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    ));
    await tester.pumpAndSettle();

    expect(AppSettings.instance.chartMatchesPalette, isFalse);   // off by default
    await tester.tap(find.text('EKG chart in palette colors'));
    await tester.pumpAndSettle();
    expect(AppSettings.instance.chartMatchesPalette, isTrue);
    await tester.tap(find.text('EKG chart in palette colors'));
    await tester.pumpAndSettle();
    expect(AppSettings.instance.chartMatchesPalette, isFalse);
  });

  testWidgets('the beep switch: off by default, tapping turns it on and off', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    ));
    await tester.pumpAndSettle();

    Finder beep = find.text('Beep on every heart beat');
    await tester.ensureVisible(beep);   // scroll to it if the list is longer than the screen
    await tester.pumpAndSettle();
    expect(AppSettings.instance.beepOnBeat, isFalse);
    await tester.tap(beep);
    await tester.pumpAndSettle();
    expect(AppSettings.instance.beepOnBeat, isTrue);
    await tester.tap(beep);
    await tester.pumpAndSettle();
    expect(AppSettings.instance.beepOnBeat, isFalse);
  });

  testWidgets('the advanced features switch: off by default, tapping turns it on and off', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    ));
    await tester.pumpAndSettle();

    Finder advanced = find.text('Advanced features');
    // the list builds only what is on the screen: scroll until the switch exists
    await tester.scrollUntilVisible(advanced, 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(AppSettings.instance.advancedFeatures, isFalse);
    expect(find.text('CSV with raw values only'), findsNothing);   // only with the advanced features
    await tester.tap(advanced);
    await tester.pumpAndSettle();
    expect(AppSettings.instance.advancedFeatures, isTrue);
    expect(find.text('CSV with raw values only'), findsOneWidget);
    expect(AppSettings.instance.csvRawOnlyInUse, isFalse);   // off by default
    await tester.tap(advanced);
    await tester.pumpAndSettle();
    expect(AppSettings.instance.advancedFeatures, isFalse);
  });
}

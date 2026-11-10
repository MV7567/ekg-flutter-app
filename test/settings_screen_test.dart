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
}

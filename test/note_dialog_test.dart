import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/l10n/app_localizations.dart';
import 'package:ecg_ble_app/screens/recording_actions.dart';

void main() {
  // opens the note dialog, closes it with [close], returns what the dialog gave back
  Future<String?> openAndClose(WidgetTester tester, Future<void> Function() close) async {
    String? result = 'not closed';
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async {
            result = await showDialog<String>(context: context, builder: (_) => const NoteDialog(currentNote: 'rest'));
          },
          child: const Text('open'),
        ),
      )),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(NoteDialog), findsOneWidget);
    await close();
    await tester.pumpAndSettle();   // the whole closing animation: the red screen came here
    expect(find.byType(NoteDialog), findsNothing);
    expect(tester.takeException(), isNull);
    return result;
  }

  testWidgets('save gives the edited text, closing does not crash', (tester) async {
    String? note = await openAndClose(tester, () async {
      await tester.enterText(find.byType(TextField), 'after running');
      await tester.tap(find.text('SAVE'));
    });
    expect(note, 'after running');
  });

  testWidgets('cancel gives null', (tester) async {
    expect(await openAndClose(tester, () => tester.tap(find.text('CANCEL'))), isNull);
  });

  testWidgets('a tap outside the dialog gives null', (tester) async {
    expect(await openAndClose(tester, () => tester.tapAt(const Offset(5, 5))), isNull);
  });
}

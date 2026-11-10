import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

// every language file must have every text of the English template,
// a missing one would silently show English in the middle of Polish
void main() {
  // keys of an .arb file without the "@..." descriptions
  Set<String> keys(String path) {
    Map<String, dynamic> json = jsonDecode(File(path).readAsStringSync());
    return json.keys.where((key) => !key.startsWith('@')).toSet();
  }

  Set<String> english = keys('lib/l10n/app_en.arb');

  for (FileSystemEntity file in Directory('lib/l10n').listSync()) {
    if (!file.path.endsWith('.arb') || file.path.endsWith('app_en.arb')) continue;
    test('${file.uri.pathSegments.last} has every text of app_en.arb', () {
      expect(english.difference(keys(file.path)), isEmpty);   // shows the missing keys
    });
  }
}

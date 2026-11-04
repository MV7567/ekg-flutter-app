import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/ekg_buffer.dart';

void main() {
  test('buffer that is not full keeps samples in order', () {
    final buffer = EkgBuffer(5);
    buffer.add(1);
    buffer.add(2);
    buffer.add(3);

    expect(buffer.length, 3);
    expect(buffer[0], 1); // oldest
    expect(buffer[2], 3); // newest
  });

  test('full buffer overwrites the oldest samples', () {
    final buffer = EkgBuffer(5);
    for (int i = 1; i <= 7; i++) {
      buffer.add(i.toDouble()); // 1..7, but only 5 places
    }

    // 1 and 2 were overwritten, 3..7 are left
    expect(buffer.length, 5);
    expect([for (int i = 0; i < buffer.length; i++) buffer[i]], [3, 4, 5, 6, 7]);
  });

  test('clear empties the buffer', () {
    final buffer = EkgBuffer(5);
    buffer.add(1);
    buffer.clear();
    expect(buffer.length, 0);
  });

  test('index outside the stored samples is an error (debug mode)', () {
    final buffer = EkgBuffer(5);
    buffer.add(1);
    buffer.add(2);

    expect(buffer[1], 2);
    expect(() => buffer[2], throwsA(isA<AssertionError>()));    // only 2 samples stored
    expect(() => buffer[-1], throwsA(isA<AssertionError>()));
  });
}

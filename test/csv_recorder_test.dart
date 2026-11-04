import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/recording/csv_recorder.dart';

void main() {
  test('one CSV line: sample, time (3 decimals), raw, mV (4 decimals)', () {
    expect(CsvRecorder.csvLine(0, 0), '0,0.000,0,0.0000');
    expect(CsvRecorder.csvLine(1, 1), '1,0.004,1,0.0061');           // 1 sample = 4 ms, 1 LSB = 6.1 uV
    expect(CsvRecorder.csvLine(250, -1475), '250,1.000,-1475,-9.0030'); // 1 s, the ~ -9 mV offset
  });

  test('decimal point is always a dot, never a comma', () {
    // a comma inside a number would break the columns of the CSV
    expect(CsvRecorder.csvLine(123, 4567).split(',').length, 4);
  });
}

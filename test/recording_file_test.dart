import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/ekg_config.dart';
import 'package:ecg_ble_app/recording/recording_file.dart';

// header exactly as CsvRecorder writes it (format 1)
const header = [
  '# EKG recording, device: ESP32_EKG',
  '# format: 1',
  '# start: 2026-11-04T14:30:05',
  '# sample rate: 250 Hz, gain: 12, 1 LSB = 6.10 uV',
  '# lost BLE packets are skipped, the sample numbers jump over the gap',
  'sample,time_s,raw,mV',
];

void main() {
  test('only ekg_*.csv files are recordings', () {
    expect(RecordingInfo.isRecordingFileName('ekg_2026-11-04_14-30-05.csv'), isTrue);
    expect(RecordingInfo.isRecordingFileName('ekg_2026-11-04_14-30-05_2.csv'), isTrue);
    expect(RecordingInfo.isRecordingFileName('ekg_data_123.txt'), isFalse);
    expect(RecordingInfo.isRecordingFileName('photo.jpg'), isFalse);
  });

  test('header of format 1 is read', () {
    expect(RecordingInfo.parseDeviceName(header), 'ESP32_EKG');
    expect(RecordingInfo.parseFormatVersion(header), 1);
    expect(RecordingInfo.parseStart(header, 'ekg_2000-01-01_00-00-00.csv'),
        DateTime(2026, 11, 4, 14, 30, 5));   // the header wins over the file name
  });

  test('old file without format and start lines: format 0, date from the file name', () {
    const oldHeader = ['sample,time_s,raw,mV'];
    expect(RecordingInfo.parseFormatVersion(oldHeader), 0);
    expect(RecordingInfo.parseDeviceName(oldHeader), '');
    expect(RecordingInfo.parseStart(oldHeader, 'ekg_2026-10-21_22-24-59.csv'),
        DateTime(2026, 10, 21, 22, 24, 59));
    expect(RecordingInfo.parseStart(oldHeader, 'something.csv'), isNull);
  });

  test('duration from the last sample number', () {
    expect(RecordingInfo.durationFromLastLines(['248,0.992,10,0.0610', '249,0.996,12,0.0732']),
        const Duration(seconds: 1));   // samples 0..249 = 250 samples = 1 s
  });

  test('samples: header skipped, mV column used, index = sample number', () {
    List<double> mv = RecordingInfo.parseMillivolts([...header, '0,0.000,0,0.0000', '1,0.004,164,1.0000']);
    expect(mv, [0.0, 1.0]);
  });

  test('samples: without the mV column raw x LSB is used', () {
    List<double> mv = RecordingInfo.parseMillivolts(['0,0.000,1000', '1,0.004,-1000']);
    expect(mv[0], closeTo(1000 * millivoltsPerLsb, 1e-4));   // ~6.1 mV
    expect(mv[1], closeTo(-1000 * millivoltsPerLsb, 1e-4));
  });

  test('samples: a gap from lost packets is filled with the last value, cut line skipped', () {
    List<double> mv = RecordingInfo.parseMillivolts(['0,0.000,0,0.5', '3,0.012,0,2.0', '4,0.0']);
    expect(mv, [0.5, 0.5, 0.5, 2.0]);   // samples 1 and 2 were lost
  });

  test('a cut last line is skipped, an empty file has duration 0', () {
    expect(RecordingInfo.durationFromLastLines(['499,1.996,10,0.0610', '50']),
        const Duration(seconds: 2));
    expect(RecordingInfo.durationFromLastLines(header), Duration.zero);
  });
}

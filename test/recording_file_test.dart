import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/ekg_config.dart';
import 'package:ecg_ble_app/recording/csv_recorder.dart';
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

  // ---- the footer: average bpm and note at the end of the file ----

  test('footer lines: only what is known', () {
    expect(CsvRecorder.footerLines(averageBpm: 78, note: 'rest'), ['# average bpm: 78', '# note: rest']);
    expect(CsvRecorder.footerLines(averageBpm: null, note: ''), isEmpty);   // too few beats, no note
    expect(CsvRecorder.footerLines(note: '   '), isEmpty);                 // only spaces = no note
  });

  test('note: one line, trimmed, at most 80 characters', () {
    expect(CsvRecorder.cleanNote('  po bieganiu \n zmęczony\r\n'), 'po bieganiu zmęczony');
    expect(CsvRecorder.cleanNote('x' * 200).length, CsvRecorder.maxNoteLength);
  });

  test('note: the LAST note line counts (a changed note is appended), "" removes it', () {
    List<String> tail = ['499,1.996,10,0.0610', '# average bpm: 78', '# note: rest', '# note: after running'];
    expect(RecordingInfo.parseNote(tail), 'after running');
    expect(RecordingInfo.parseNote([...tail, '# note: ']), '');
    expect(RecordingInfo.parseNote(['499,1.996,10,0.0610']), '');   // old file
    expect(RecordingInfo.parseAverageBpm(tail), 78);
    expect(RecordingInfo.parseAverageBpm(['499,1.996,10,0.0610']), isNull);
  });

  test('the footer changes neither the duration nor the samples', () {
    List<String> lines = [...header, '0,0.000,10,0.0610', '1,0.004,20,0.1221', '# average bpm: 78', '# note: a, b, c, d'];
    expect(RecordingInfo.durationFromLastLines(lines), const Duration(milliseconds: 8));
    expect(RecordingInfo.parseMillivolts(lines).length, 2);
  });

  test('a real file: written, note changed later, read back', () async {
    Directory folder = await Directory.systemTemp.createTemp('ekg_test');
    addTearDown(() => folder.delete(recursive: true));
    File file = File('${folder.path}/ekg_2026-11-04_14-30-05.csv');
    List<String> samples = [for (int i = 0; i < 2500; i++) CsvRecorder.csvLine(i, 100)];   // 10 s
    String text = [...header, ...samples, ...CsvRecorder.footerLines(averageBpm: 74, note: 'rest')].join('\n');
    await file.writeAsString('$text\n');

    RecordingInfo info = await RecordingInfo.load(file);
    expect((info.note, info.averageBpm, info.duration), ('rest', 74, const Duration(seconds: 10)));

    await CsvRecorder.appendNote(file.path, 'after\nrunning');
    info = await RecordingInfo.load(file);
    expect(info.note, 'after running');
    expect(info.averageBpm, 74);
    expect(info.duration, const Duration(seconds: 10));
  });

  // ---- events: "# event: 5712" lines between the samples ----

  test('events: every event line, in order, nothing else', () {
    List<String> lines = [...header, '0,0.000,10,0.0610', '# event: 1', '1,0.004,20,0.1221', '# event: 5712',
        '# event: broken', '# note: event'];
    expect(RecordingInfo.parseEvents(lines), [1, 5712]);
    expect(RecordingInfo.parseEvents(header), isEmpty);   // a recording without events
  });

  test('a real file with events: the samples are not changed, the events are found', () async {
    Directory folder = await Directory.systemTemp.createTemp('ekg_test');
    addTearDown(() => folder.delete(recursive: true));
    File file = File('${folder.path}/ekg_2026-11-04_14-30-05.csv');
    List<String> lines = [...header];
    for (int i = 0; i < 2500; i++) {
      lines.add(CsvRecorder.csvLine(i, 100));
      if (i == 700 || i == 1800) lines.add('${CsvRecorder.eventTag} $i');   // like writeEvent()
    }
    await file.writeAsString('${lines.join('\n')}\n');

    RecordingData data = RecordingInfo.loadForView(file.path);
    expect(data.millivolts.length, 2500);
    expect(data.events, [700, 1800]);
    expect((await RecordingInfo.load(file)).duration, const Duration(seconds: 10));
  });

  // ---- "raw only" files: "sample,raw" ----

  test('raw only: the 2nd column is the raw value, gaps filled, the duration from 2 columns', () {
    List<String> rawHeader = [...header.sublist(0, header.length - 1), CsvRecorder.columnsRawOnly];
    expect(CsvRecorder.rawCsvLine(5712, -1475), '5712,-1475');
    List<String> lines = [...rawHeader, '0,1000', '1,-1000', '3,0', '# average bpm: 70'];
    List<double> mv = RecordingInfo.parseMillivolts(lines);
    expect(mv.length, 4);                                            // sample 2 was lost, filled
    expect(mv[0], closeTo(1000 * millivoltsPerLsb, 1e-4));
    expect(mv[2], mv[1]);
    expect(RecordingInfo.durationFromLastLines(lines), const Duration(milliseconds: 16));   // 4 samples
  });

  test('a real raw only file: written by CsvRecorder lines, read like a full one', () async {
    Directory folder = await Directory.systemTemp.createTemp('ekg_test');
    addTearDown(() => folder.delete(recursive: true));
    File raw = File('${folder.path}/ekg_2026-11-04_14-30-05.csv');
    File full = File('${folder.path}/ekg_2026-11-04_14-31-05.csv');
    List<String> rawHeader = [...header.sublist(0, header.length - 1), CsvRecorder.columnsRawOnly];
    List<String> rawLines = [...rawHeader, for (int i = 0; i < 2500; i++) CsvRecorder.rawCsvLine(i, i % 300 - 150), '# event: 700'];
    List<String> fullLines = [...header, for (int i = 0; i < 2500; i++) CsvRecorder.csvLine(i, i % 300 - 150), '# event: 700'];
    await raw.writeAsString('${rawLines.join('\n')}\n');
    await full.writeAsString('${fullLines.join('\n')}\n');

    RecordingData a = RecordingInfo.loadForView(raw.path);
    RecordingData b = RecordingInfo.loadForView(full.path);
    expect(a.millivolts.length, 2500);
    for (int i = 0; i < 2500; i++) {
      expect(a.millivolts[i], closeTo(b.millivolts[i], 1e-3));   // the same signal (mV rounded to 4 places in the full file)
    }
    expect(a.events, [700]);
    expect((await RecordingInfo.load(raw)).duration, const Duration(seconds: 10));
    expect(await raw.length(), lessThan(await full.length() * 0.6));   // about half the size
  });

  // ---- the internal test signal of the ADS1194 ----

  test('test signal: a real file with the mark, no beats, the amplitude of the square', () async {
    Directory folder = await Directory.systemTemp.createTemp('ekg_test');
    addTearDown(() => folder.delete(recursive: true));
    File file = File('${folder.path}/ekg_2026-11-04_14-30-05.csv');
    // like the real recording: 229 / -99 raw (2.002 mV), ~1 Hz (128 samples up, 128 down), an edge sample between
    int raw(int i) => i % 128 == 0 ? 65 : ((i ~/ 128).isEven ? 229 : -99);
    List<String> lines = [...header, CsvRecorder.testSignalTag, for (int i = 0; i < 2500; i++) CsvRecorder.csvLine(i, raw(i))];
    await file.writeAsString('${lines.join('\n')}\n');

    RecordingData data = RecordingInfo.loadForView(file.path);
    expect(data.beats, isEmpty);          // the edges are not heart beats
    expect(data.artifacts, isEmpty);
    expect(data.testPeakToPeakMv, closeTo(328 * millivoltsPerLsb, 1e-3));   // 2.002 mV
    expect((await RecordingInfo.load(file)).isTestSignal, isTrue);
    expect(RecordingInfo.expectedTestPeakToPeakMv, closeTo(2.0, 1e-9));
  });

  test('a normal recording is not a test signal', () async {
    Directory folder = await Directory.systemTemp.createTemp('ekg_test');
    addTearDown(() => folder.delete(recursive: true));
    File file = File('${folder.path}/ekg_2026-11-04_14-30-05.csv');
    List<String> lines = [...header, for (int i = 0; i < 500; i++) CsvRecorder.csvLine(i, 0)];
    await file.writeAsString('${lines.join('\n')}\n');
    expect((await RecordingInfo.load(file)).isTestSignal, isFalse);
    expect(RecordingInfo.loadForView(file.path).testPeakToPeakMv, isNull);
  });
}

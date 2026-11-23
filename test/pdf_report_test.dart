import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:ecg_ble_app/artifact_detector.dart';
import 'package:ecg_ble_app/ekg_test_signal.dart';
import 'package:ecg_ble_app/filters/biquad_filter.dart';
import 'package:ecg_ble_app/heart_rate_detector.dart';
import 'package:ecg_ble_app/l10n/app_localizations.dart';
import 'package:ecg_ble_app/recording/pdf_report.dart';
import 'package:ecg_ble_app/screens/recording_actions.dart';
import 'package:ecg_ble_app/af_detector.dart';
import 'package:ecg_ble_app/rhythm_analysis.dart';
import 'package:ecg_ble_app/rr_stats.dart';

const int fs = 250;

// [seconds] of the test EKG scaled to a QRS of [scale] x ~1 mV, filtered like in the app
Float32List filteredEkg(double seconds, {double scale = 1}) {
  EkgDisplayFilter filter = EkgDisplayFilter(fs.toDouble());
  return Float32List.fromList([
    for (int i = 0; i < seconds * fs; i++) filter.process(scale * EkgTestSignal.millivoltsAt(i / fs)),
  ]);
}

void main() {
  test('gain: the usual beats fill at most 70 % of the half strip', () {
    // a strip is 30 mm high: 15 mm above 0 mV, 70 % = 10.5 mm
    Float32List constant(double mv) => Float32List.fromList(List.filled(10 * fs, mv));
    expect(PdfReport.chooseGain(constant(1.0), fs), 10);    // 10 mm, the standard
    expect(PdfReport.chooseGain(constant(0.3), fs), 20);    // 6 mm (40 mm/mV would be 12 mm)
    expect(PdfReport.chooseGain(constant(0.1), fs), 80);    // 8 mm
    expect(PdfReport.chooseGain(Float32List(10), fs), 10);  // less than 1 s: the standard
  });

  test('strips: the whole recording, at most 10 (60 s)', () {
    expect(PdfReport.stripCount(7 * fs, fs), 2);     // 6 s + 1 s
    expect(PdfReport.stripCount(60 * fs, fs), 10);
    expect(PdfReport.stripCount(300 * fs, fs), 10);
    expect(PdfReport.stripCount(0, fs), 0);
  });

  test('strips start at 0:02, a recording shorter than 2 s + 1 strip from 0:00', () {
    expect(PdfReport.firstStripSample(180 * fs, fs), 2 * fs);
    expect(PdfReport.firstStripSample(8 * fs, fs), 2 * fs);       // exactly 2 s + 6 s
    expect(PdfReport.firstStripSample(8 * fs - 1, fs), 0);
    expect(PdfReport.firstStripSample(0, fs), 0);
  });

  test('event strips: event in the middle, only events after the main strips, at most 10', () {
    int samples = 180 * fs;                  // 3 min
    int from = 2 * fs, end = 62 * fs;        // the main strips 0:02 - 1:02
    expect(PdfReport.eventStrips([30 * fs, 122 * fs], samples, fs, from, end),
        [(122 * fs, 119 * fs)]);             // 0:30 is already on the main strips, 2:02 -> 1:59 - 2:05
    expect(PdfReport.eventStrips([fs, 179 * fs], samples, fs, from, end),
        [(fs, 0), (179 * fs, 174 * fs)]);    // at the edges the strip moves inside the recording
    expect(PdfReport.eventStrips([for (int s = 70; s < 170; s += 5) s * fs], samples, fs, from, end).length,
        PdfReport.maxEventStrips);
    expect(PdfReport.eventStrips([fs], 5 * fs, fs, 0, 5 * fs), isEmpty);   // shorter than one strip
  });

  test('a whole report is a PDF, with and without statistics', () async {
    // the same fonts as the app, read straight from the files (no Flutter assets in a plain test)
    pw.Font regular = pw.Font.ttf(ByteData.sublistView(File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync()));
    pw.Font bold = pw.Font.ttf(ByteData.sublistView(File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync()));
    AppLocalizations t = lookupAppLocalizations(const Locale('pl'));

    Float32List mv = filteredEkg(70, scale: 0.3);   // 70 s: more than 10 strips, small QRS
    List<int> beats = HeartRateDetector.findBeats(mv, fs);
    List<int> bigeminy = [fs];
    for (int rr in [...List.filled(10, 200), for (int k = 0; k < 25; k++) ...[130, 270]]) {
      bigeminy.add(bigeminy.last + rr);
    }
    expect(RhythmAnalysis.findPremature(bigeminy, fs).length, 25);
    // random intervals 0.5-1.1 s from 10 s on: an irregular rhythm episode
    Random random = Random(4);
    List<int> irregularBeats = [10 * fs];
    for (int k = 0; k < 60; k++) {
      irregularBeats.add(irregularBeats.last + 125 + random.nextInt(150));
    }
    AfDetector irregular = AfDetector.analyze(irregularBeats, fs);
    expect(irregular.suspected, isTrue);
    Uint8List full = await PdfReport.build(
      t: t, regular: regular, bold: bold,
      start: DateTime(2026, 11, 12, 16, 25), deviceName: 'ESP32_EKG', note: 'spoczynek, zażółć gęślą jaźń',
      millivolts: mv, beats: beats, events: [5 * fs, 42 * fs, 66 * fs],
      artifacts: [Artifact(20 * fs, 22 * fs), Artifact(65 * fs, 66 * fs)], stats: RrStats.fromBeats(beats, fs), sampleRateHz: fs,
      // more premature beats than fit in the info line, some on the strips
      // (bigeminy: 10 normal intervals of 200 samples, then 25 x early 130 + pause 270 = 25 premature)
      rhythm: RhythmAnalysis.analyze(bigeminy, fs, 52),
      // an irregular part from 10 s to the end: a band on the strips and the info line
      af: irregular,
    );
    expect(String.fromCharCodes(full.sublist(0, 5)), '%PDF-');

    // with the signal: the median beat, the QRS width, the pauses line
    Uint8List withShape = await PdfReport.build(
      t: t, regular: regular, bold: bold,
      start: null, deviceName: '', note: '',
      millivolts: mv, beats: beats, stats: RrStats.fromBeats(beats, fs), sampleRateHz: fs,
      rhythm: RhythmAnalysis.analyze(beats, fs, 72, signal: mv),
    );
    expect(String.fromCharCodes(withShape.sublist(0, 5)), '%PDF-');

    Uint8List short = await PdfReport.build(
      t: t, regular: regular, bold: bold,
      start: null, deviceName: '', note: '',
      millivolts: filteredEkg(2), beats: const [], stats: null, sampleRateHz: fs,
    );
    expect(String.fromCharCodes(short.sublist(0, 5)), '%PDF-');

    // a test signal recording: the calibration check instead of the statistics
    Uint8List test = await PdfReport.build(
      t: t, regular: regular, bold: bold,
      start: null, deviceName: 'ESP32_EKG', note: '',
      millivolts: filteredEkg(10), beats: const [], stats: null, sampleRateHz: fs, testPeakToPeakMv: 2.002,
    );
    expect(String.fromCharCodes(test.sublist(0, 5)), '%PDF-');
  });

  test('the calibration text: expected, measured and the error', () {
    AppLocalizations en = lookupAppLocalizations(const Locale('en'));
    expect(testSignalResult(en, 2.002), startsWith('Expected 2.000 mV peak to peak'));
    expect(testSignalResult(en, 2.002), contains('measured 2.002 mV (+0.1 %)'));
    expect(testSignalResult(en, 1.9), contains('(-5.0 %)'));
  });
}

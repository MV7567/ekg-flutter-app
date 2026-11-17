import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:ecg_ble_app/ekg_test_signal.dart';
import 'package:ecg_ble_app/filters/biquad_filter.dart';
import 'package:ecg_ble_app/heart_rate_detector.dart';
import 'package:ecg_ble_app/l10n/app_localizations.dart';
import 'package:ecg_ble_app/recording/pdf_report.dart';
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

  test('a whole report is a PDF, with and without statistics', () async {
    // the same fonts as the app, read straight from the files (no Flutter assets in a plain test)
    pw.Font regular = pw.Font.ttf(ByteData.sublistView(File('assets/fonts/Roboto-Regular.ttf').readAsBytesSync()));
    pw.Font bold = pw.Font.ttf(ByteData.sublistView(File('assets/fonts/Roboto-Bold.ttf').readAsBytesSync()));
    AppLocalizations t = lookupAppLocalizations(const Locale('pl'));

    Float32List mv = filteredEkg(70, scale: 0.3);   // 70 s: more than 10 strips, small QRS
    List<int> beats = HeartRateDetector.findBeats(mv, fs);
    Uint8List full = await PdfReport.build(
      t: t, regular: regular, bold: bold,
      start: DateTime(2026, 11, 12, 16, 25), deviceName: 'ESP32_EKG', note: 'spoczynek, zażółć gęślą jaźń',
      millivolts: mv, beats: beats, events: [5 * fs, 42 * fs], stats: RrStats.fromBeats(beats, fs), sampleRateHz: fs,
    );
    expect(String.fromCharCodes(full.sublist(0, 5)), '%PDF-');

    Uint8List short = await PdfReport.build(
      t: t, regular: regular, bold: bold,
      start: null, deviceName: '', note: '',
      millivolts: filteredEkg(2), beats: const [], stats: null, sampleRateHz: fs,
    );
    expect(String.fromCharCodes(short.sublist(0, 5)), '%PDF-');
  });
}

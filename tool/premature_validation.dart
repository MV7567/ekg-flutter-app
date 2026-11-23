// Validation of the premature beat finder (RhythmAnalysis.findPremature) on the
// MIT-BIH Arrhythmia Database, the same data and pipeline as tool/mitbih_validation.dart.
//
// usage (from the app folder):
//   dart run tool/premature_validation.dart <mitdb folder> [results.csv]
//
// the reference premature beats: the beats annotated by the cardiologists as
//   V (premature ventricular), A (atrial premature), a (aberrated atrial premature),
//   J (nodal premature), S (supraventricular premature)
// left out:
//   - the 4 paced records (a pacemaker sets the rhythm)
//   - atrial fibrillation / flutter episodes (rhythm "(AFIB", "(AFL"): there every interval
//     is irregular, "premature" has no meaning, this is a separate check (step 3)
//   - the first 10 s (the detector learning)
// a found premature beat within 150 ms of a reference premature beat = TP, otherwise FP;
// a reference premature beat without one = FN
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';
import 'package:ecg_ble_app/rhythm_analysis.dart';
import 'mitbih_validation.dart' hide main;

const Set<int> prematureCodes = {4, 5, 7, 8, 9};   // a V J A S
const int pvcCode = 5;
const Set<String> fibrillation = {'(AFIB', '(AFL'};

class RecordData {
  RecordData(this.record, this.beats, this.reference, this.referenceV, this.inFibrillation);
  final String record;
  final List<int> beats;              // found by the app detector, at 250 Hz
  final List<double> reference;       // the reference premature beats, seconds
  final List<double> referenceV;      // only the ventricular ones (V)
  final bool Function(double seconds) inFibrillation;
}

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/premature_validation.dart <mitdb folder> [results.csv]');
    exit(1);
  }
  String folder = args[0];
  List<String> records = File('$folder/RECORDS').readAsLinesSync().map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  List<RecordData> data = [];
  for (String rec in records) {
    if (pacedRecords.contains(rec)) continue;
    Header h = readHeader('$folder/$rec.hea');
    Float64List mv = resample(readLead0('$folder/$rec.dat', h), h.sampleRate);
    List<Annotation> annotations = readAnnotations('$folder/$rec.atr');

    // the atrial fibrillation / flutter episodes, in seconds
    List<(double, double)> episodes = [];
    double? start;
    for (Annotation a in annotations) {
      bool af = fibrillation.contains(a.rhythm);
      double t = a.time / h.sampleRate;
      if (af && start == null) start = t;
      if (!af && start != null) {
        episodes.add((start, t));
        start = null;
      }
    }
    if (start != null) episodes.add((start, double.infinity));
    bool inFibrillation(double t) => episodes.any((e) => t >= e.$1 - 1 && t <= e.$2 + 1);

    bool counted(Annotation a) =>
        a.time / h.sampleRate >= skipSeconds && !fibrillation.contains(a.rhythm) && !inFibrillation(a.time / h.sampleRate);
    data.add(RecordData(
      rec,
      detect(mv),
      [for (Annotation a in annotations) if (prematureCodes.contains(a.code) && counted(a)) a.time / h.sampleRate],
      [for (Annotation a in annotations) if (a.code == pvcCode && counted(a)) a.time / h.sampleRate],
      inFibrillation,
    ));
    stdout.write('.');
  }
  print('');

  // one setting over all records: per-record results and the totals
  (Result, Result, List<Result>) run(double prematureRatio, double pauseRatio) {
    List<Result> perRecord = [];
    int vTp = 0, vFn = 0;
    for (RecordData d in data) {
      List<double> found = [
        for (int b in RhythmAnalysis.findPremature(d.beats, targetRate,
            prematureRatio: prematureRatio, pauseRatio: pauseRatio))
          if (b / targetRate >= skipSeconds && !d.inFibrillation(b / targetRate)) b / targetRate,
      ];
      perRecord.add(compare(d.record, '', d.reference, found));
      Result v = compare(d.record, '', d.referenceV, found);   // only Se has a meaning here
      vTp += v.tp;
      vFn += v.fn;
    }
    int tp = perRecord.fold(0, (s, r) => s + r.tp);
    int fn = perRecord.fold(0, (s, r) => s + r.fn);
    int fp = perRecord.fold(0, (s, r) => s + r.fp);
    return (Result('all', '', tp, fn, fp), Result('V', '', vTp, vFn, 0), perRecord);
  }

  var (total, v, perRecord) = run(RhythmAnalysis.prematureRatio, RhythmAnalysis.pauseRatio);
  print('record  ref  TP   FN   FP   Se %    +P %');
  for (Result r in perRecord) {
    print('${r.record.padRight(6)} ${(r.tp + r.fn).toString().padLeft(4)} ${r.tp.toString().padLeft(4)} '
        '${r.fn.toString().padLeft(4)} ${r.fp.toString().padLeft(4)} '
        '${(r.tp + r.fn == 0 ? '--' : percent(r.se)).padLeft(6)} ${(r.tp + r.fp == 0 ? '--' : percent(r.ppv)).padLeft(7)}');
  }
  print('');
  print('settings: premature < ${RhythmAnalysis.prematureRatio} x usual, pause >= ${RhythmAnalysis.pauseRatio} x usual');
  print('${data.length} records (without paced), AF/AFL episodes left out');
  print('premature beats: ${total.tp + total.fn} reference, ${total.tp} TP, ${total.fn} FN, ${total.fp} FP, '
      'Se ${percent(total.se)} %, +P ${percent(total.ppv)} %');
  print('of them ventricular (V): ${v.tp + v.fn} reference, Se ${percent(v.se)} %');

  // how much the result depends on the two limits
  print('');
  print('sensitivity to the limits (Se % / +P %):');
  List<double> pauses = [0.8, 0.9, 1.0];
  print('premature \\ pause  ${pauses.map((p) => p.toStringAsFixed(1).padLeft(13)).join()}');
  for (double p in [0.75, 0.80, 0.85, 0.90]) {
    String row = p.toStringAsFixed(2).padRight(18);
    for (double q in pauses) {
      Result r = run(p, q).$1;
      row += '${percent(r.se)}/${percent(r.ppv)}'.padLeft(13);
    }
    print(row);
  }

  if (args.length > 1) {
    StringBuffer csv = StringBuffer('record,reference,TP,FN,FP\n');
    for (Result r in perRecord) {
      csv.writeln('${r.record},${r.tp + r.fn},${r.tp},${r.fn},${r.fp}');
    }
    File(args[1]).writeAsStringSync(csv.toString());
    print('saved: ${args[1]}');
  }
}

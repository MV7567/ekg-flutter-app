// Validation of the beat detector on the MIT-BIH Arrhythmia Database (PhysioNet, public data,
// 48 half-hour 2-lead recordings at 360 Hz, every beat annotated by cardiologists).
//
// usage (from the app folder):
//   dart run tool/mitbih_validation.dart <folder with 100.dat, 100.hea, 100.atr ...> [results.csv]
//
// what it does for every record:
//   1. reads lead 0 (the .dat file, WFDB format 212) and converts it to mV (gain and baseline from the .hea)
//   2. resamples it 360 Hz -> 250 Hz (linear interpolation), the sample rate of our device
//   3. runs exactly the app pipeline for a saved recording:
//      SpikeRemover -> EkgDisplayFilter -> HeartRateDetector.findBeats
//   4. compares the found beats with the reference beat annotations (the .atr file):
//      a found beat within 150 ms of a reference beat = true positive (TP), a reference beat
//      without one = false negative (FN, missed), a found beat without one = false positive (FP)
//      (150 ms = the matching window of the ANSI/AAMI EC57 standard)
//   5. Se = TP / (TP + FN) (sensitivity), +P = TP / (TP + FP) (positive predictivity)
// the first 10 s of every record are not counted: the detector settles and learns there
// a command line tool: the results are printed
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';
import 'package:ecg_ble_app/filters/biquad_filter.dart';
import 'package:ecg_ble_app/filters/spike_remover.dart';
import 'package:ecg_ble_app/heart_rate_detector.dart';

const int targetRate = 250;               // our device
const double matchWindowSeconds = 0.150;  // EC57
const double skipSeconds = 10;            // the detector learning at the start

// the annotation codes that are heart beats (WFDB ecgcodes.h, isqrs):
// N L R a V F J A S E j / Q B ? e f r
const Set<int> beatCodes = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 25, 30, 34, 38, 41};

// the 4 records with a pacemaker, usually reported separately (AAMI)
const Set<String> pacedRecords = {'102', '104', '107', '217'};

class Header {
  Header(this.sampleRate, this.samples, this.gain, this.baseline, this.lead);
  final double sampleRate;
  final int samples;
  final double gain;      // ADC units per mV
  final int baseline;     // ADC value of 0 mV
  final String lead;      // MLII, V5, ...
}

// "100 2 360 650000" then one line per signal: "100.dat 212 200 11 1024 995 -22131 0 MLII"
Header readHeader(String path) {
  List<String> lines = File(path).readAsLinesSync().where((l) => !l.startsWith('#') && l.trim().isNotEmpty).toList();
  List<String> record = lines[0].split(RegExp(r'\s+'));
  List<String> signal0 = lines[1].split(RegExp(r'\s+'));
  // the gain can be "200" or "200(0)/mV", the baseline is then in the brackets
  String gainField = signal0[2];
  double gain = double.parse(RegExp(r'^[\d.]+').firstMatch(gainField)!.group(0)!);
  int baseline = int.parse(signal0[4]);   // the ADC zero, the same as the baseline in MIT-BIH
  // the sample rate can be "250/360" (QT Database: the sample rate / the counter rate), only the first part counts
  return Header(double.parse(record[2].split('/').first), int.parse(record[3]), gain, baseline,
      signal0.length > 8 ? signal0[8] : '?');
}

// format 212: 2 signals, 12 bits each, packed into 3 bytes per frame
// byte0 = low 8 bits of signal 0, byte1 low nibble = its high 4 bits,
// byte1 high nibble = high 4 bits of signal 1, byte2 = its low 8 bits
Float64List readLead0(String path, Header h) {
  Uint8List bytes = File(path).readAsBytesSync();
  int frames = bytes.length ~/ 3;
  Float64List mv = Float64List(frames);
  for (int f = 0; f < frames; f++) {
    int value = bytes[3 * f] | ((bytes[3 * f + 1] & 0x0F) << 8);
    if (value >= 2048) value -= 4096;   // 12-bit two's complement
    mv[f] = (value - h.baseline) / h.gain;
  }
  return mv;
}

// one annotation: its time (in samples), its code and the rhythm at that moment
// ("(N" normal sinus, "(AFIB" atrial fibrillation, "(B" bigeminy ..., "" before the first one)
class Annotation {
  Annotation(this.time, this.code, this.rhythm);
  final int time, code;
  final String rhythm;
}

const int rhythmCode = 28;   // a rhythm change, the rhythm name is in its AUX text

// MIT annotation format: 16-bit little-endian words, code = top 6 bits, time step = low 10 bits
// special codes: 59 SKIP (a 32-bit time step follows), 60-62 NUM/SUB/CHN, 63 AUX (text follows,
// it belongs to the annotation before it)
List<Annotation> readAnnotations(String path) {
  Uint8List b = File(path).readAsBytesSync();
  List<Annotation> annotations = [];
  int time = 0;
  int lastCode = -1;
  String rhythm = '';
  int i = 0;
  while (i + 1 < b.length) {
    int word = b[i] | (b[i + 1] << 8);
    i += 2;
    int code = word >> 10;
    int step = word & 0x3FF;
    if (code == 0 && step == 0) break;    // the end
    if (code == 59) {                     // SKIP: the step is the next 4 bytes, the high word first
      int high = b[i] | (b[i + 1] << 8);
      int low = b[i + 2] | (b[i + 3] << 8);
      time += (high << 16) | low;
      i += 4;
    } else if (code == 63) {              // AUX: step = the length of the text, padded to even
      if (lastCode == rhythmCode) {
        rhythm = String.fromCharCodes(b.sublist(i, i + step)).replaceAll('\x00', '').trim();
      }
      i += step + (step & 1);
    } else if (code >= 60) {
      // NUM, SUB, CHN: only change a field of the current annotation
    } else {
      time += step;
      lastCode = code;
      annotations.add(Annotation(time, code, rhythm));
    }
  }
  return annotations;
}

List<int> readBeatTimes(String path) =>
    [for (Annotation a in readAnnotations(path)) if (beatCodes.contains(a.code)) a.time];

// linear interpolation from the original rate to 250 Hz
Float64List resample(Float64List x, double fromRate) {
  int n = (x.length * targetRate / fromRate).floor();
  Float64List y = Float64List(n);
  for (int k = 0; k < n; k++) {
    double t = k * fromRate / targetRate;   // position in the original samples
    int i = t.floor();
    double frac = t - i;
    y[k] = i + 1 < x.length ? x[i] * (1 - frac) + x[i + 1] * frac : x[x.length - 1];
  }
  return y;
}

// the app pipeline for a saved recording (see RecordingInfo.filterMillivolts and loadForView)
List<double> filterLikeApp(Float64List mv) {
  EkgDisplayFilter filter = EkgDisplayFilter(targetRate.toDouble());
  SpikeRemover spikes = SpikeRemover();
  return [for (double x in mv) filter.process(spikes.process(x))];
}

List<int> detect(Float64List mv) => HeartRateDetector.findBeats(filterLikeApp(mv), targetRate);

class Result {
  Result(this.record, this.lead, this.tp, this.fn, this.fp);
  final String record, lead;
  final int tp, fn, fp;
  double get se => tp + fn == 0 ? 0 : tp / (tp + fn);
  double get ppv => tp + fp == 0 ? 0 : tp / (tp + fp);
}

// matching in seconds: both lists sorted, every reference beat takes the nearest free
// detection within the window
Result compare(String record, String lead, List<double> reference, List<double> detected) {
  int tp = 0, fn = 0;
  int j = 0;
  List<bool> used = List.filled(detected.length, false);
  for (double r in reference) {
    while (j < detected.length && detected[j] < r - matchWindowSeconds) {
      j++;
    }
    int best = -1;
    double bestDistance = double.infinity;
    for (int k = j; k < detected.length && detected[k] <= r + matchWindowSeconds; k++) {
      double d = (detected[k] - r).abs();
      if (!used[k] && d < bestDistance) {
        best = k;
        bestDistance = d;
      }
    }
    if (best >= 0) {
      used[best] = true;
      tp++;
    } else {
      fn++;
    }
  }
  int fp = used.where((u) => !u).length;
  return Result(record, lead, tp, fn, fp);
}

String percent(double x) => (100 * x).toStringAsFixed(2);

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/mitbih_validation.dart <mitdb folder> [results.csv]');
    exit(1);
  }
  String folder = args[0];
  List<String> records = File('$folder/RECORDS').readAsLinesSync().map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  List<Result> results = [];
  print('record lead      TP    FN    FP   Se %    +P %');
  for (String rec in records) {
    Header h = readHeader('$folder/$rec.hea');
    Float64List mv = resample(readLead0('$folder/$rec.dat', h), h.sampleRate);
    List<double> detected = [
      for (int b in detect(mv)) if (b / targetRate >= skipSeconds) b / targetRate,
    ];
    List<double> reference = [
      for (int t in readBeatTimes('$folder/$rec.atr')) if (t / h.sampleRate >= skipSeconds) t / h.sampleRate,
    ];
    Result r = compare(rec, h.lead, reference, detected);
    results.add(r);
    print('${rec.padRight(6)} ${h.lead.padRight(5)} ${r.tp.toString().padLeft(6)} ${r.fn.toString().padLeft(5)} '
        '${r.fp.toString().padLeft(5)} ${percent(r.se).padLeft(6)} ${percent(r.ppv).padLeft(7)}'
        '${pacedRecords.contains(rec) ? '  (paced)' : ''}');
  }

  void total(String name, Iterable<Result> rs) {
    int tp = rs.fold(0, (s, r) => s + r.tp);
    int fn = rs.fold(0, (s, r) => s + r.fn);
    int fp = rs.fold(0, (s, r) => s + r.fp);
    Result t = Result(name, '', tp, fn, fp);
    print('$name: ${rs.length} records, $tp TP, $fn FN, $fp FP, Se ${percent(t.se)} %, +P ${percent(t.ppv)} %');
  }

  print('');
  total('all', results);
  total('without paced', results.where((r) => !pacedRecords.contains(r.record)));

  if (args.length > 1) {
    StringBuffer csv = StringBuffer('record,lead,paced,TP,FN,FP,Se,PPV\n');
    for (Result r in results) {
      csv.writeln('${r.record},${r.lead},${pacedRecords.contains(r.record)},${r.tp},${r.fn},${r.fp},'
          '${r.se.toStringAsFixed(5)},${r.ppv.toStringAsFixed(5)}');
    }
    File(args[1]).writeAsStringSync(csv.toString());
    print('saved: ${args[1]}');
  }
}

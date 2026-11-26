import 'dart:math';   // sqrt, pow, max
import 'qrs_width.dart';   // the median beat, the QRS start and end

// the QT interval: from the start of the QRS to the end of the T wave, the time the ventricles
// need to contract and to recover; it gets shorter when the heart is faster, so it is also given
// corrected to 60 bpm (QTc):
//   Bazett:     QTc = QT / sqrt(RR in s)    (the classic one, overcorrects at a fast heart rate)
//   Fridericia: QTc = QT / cbrt(RR in s)    (better at a fast or slow heart rate)
// a long QTc (> 450 ms men, > 460 ms women, > 500 ms clearly) can lead to dangerous arrhythmias,
// some medicines make it longer
//
// measured on the median beat (with the whole T wave, see QrsWidth.medianBeat):
//   1. the baseline: the median beat just before the QRS start (the flat PR segment)
//   2. the top of the T wave: the farthest point from the baseline between 80 ms after the QRS
//      end and the end of the median beat (up or down: the T wave can be negative)
//   3. the end of the T wave: the tangent method, the line through the steepest point of the
//      falling part of T, where it crosses the baseline (the usual way of the cardiologists)
class QtMeasurement {
  const QtMeasurement(this.qrsStart, this.tPeak, this.tEnd, this.qtMs, this.rrMs, this.tHeightMv);

  final int qrsStart, tPeak, tEnd;   // positions in the median beat
  final double qtMs;
  final double rrMs;                 // the typical RR interval of the recording
  final double tHeightMv;            // the T wave top from the baseline (negative = an inverted T)

  double get bazettMs => qtMs / sqrt(rrMs / 1000);
  double get fridericiaMs => qtMs / pow(rrMs / 1000, 1 / 3);
}

class QtInterval {
  // the QTc (Bazett, the usual one in the ECG reports) limits of the app message
  static const double shortBelowMs = 350;
  static const double longAboveMs = 460;

  // the median beat window for the QT: 300 ms before R (with the P wave) and up to 600 ms after R,
  // but at most 85 % of the RR interval, so a fast heart does not bring the next QRS into it
  static const double beforeRMs = 300;
  static const double maxAfterRMs = 600;
  static double afterRMs(double rrMs) => min(maxAfterRMs, 0.85 * rrMs);

  static const double tSearchAfterQrsMs = 80;   // the T wave top is searched from here
  // ... up to 450 ms after R, at a fast heart 60 % of RR (the T top is ~250-350 ms after R,
  // later only with a very long QT): further on there is the U wave or the next P wave
  static const double maxTPeakAfterRMs = 450;
  static double tPeakLimitMs(double rrMs) => min(maxTPeakAfterRMs, 0.6 * rrMs);
  static const double minTMillivolts = 0.05;    // a flatter T wave: its end can not be found
  // ... and at least 20 % of the QRS height: on the QT Database a flatter T gave many big errors
  // (its end is not clear in one lead), with T >= 20 % 96 % of the records were within 50 ms
  static const double minTShare = 0.20;
  static const double steepSearchMs = 200;      // tangent: the steepest point within 200 ms after the T top
  static const double baselineMs = 20;          // the baseline: the mean of 20 ms before the QRS start

  // beat: the median beat (mV), r: where R is in it, qrs: the QRS start and end in it
  // null = no clear T wave (too flat, cut by the end of the window)
  static QtMeasurement? measure(List<double> beat, int r, (int, int) qrs, double rrMs, int sampleRateHz,
      {bool areaMethod = true, double latestShare = 0.5, double areaWindowMs = areaWindowMs,
      double minTShare = minTShare}) {
    int ms(double v) => (v / 1000 * sampleRateHz).round();
    int start = qrs.$1, end = qrs.$2;
    int b0 = start - ms(baselineMs);
    if (b0 < 0) return null;
    double baseline = 0;
    for (int i = b0; i < start; i++) {
      baseline += beat[i];
    }
    baseline /= start - b0;

    // 2. the T top: the local tops / bottoms pointing away from the baseline (a point at the edge
    // of the search part is only a sloping ST segment or the start of the next wave);
    // of the clear ones (at least half of the biggest) the LAST one: a lowered ST segment
    // right after the QRS can be deeper than a small T wave after it
    int from = end + ms(tSearchAfterQrsMs);
    int to = beat.length - 3;
    int peakTo = min(to - 2, r + ms(tPeakLimitMs(rrMs)));
    if (from + 1 >= peakTo) return null;
    List<int> candidates = [];
    for (int i = from + 1; i < peakTo; i++) {
      bool top = beat[i] >= beat[i - 1] && beat[i] >= beat[i + 1];
      bool bottom = beat[i] <= beat[i - 1] && beat[i] <= beat[i + 1];
      if (!top && !bottom) continue;
      if (top && beat[i] < baseline || bottom && beat[i] > baseline) continue;   // must point away from it
      candidates.add(i);
    }
    if (candidates.isEmpty) return null;
    double biggest = candidates.map((i) => (beat[i] - baseline).abs()).reduce(max);
    if (biggest < minTMillivolts) return null;
    int peak = candidates.lastWhere((i) => (beat[i] - baseline).abs() >= latestShare * biggest);
    double height = beat[peak] - baseline;
    double qrsLow = beat[start], qrsHigh = beat[start];
    for (int i = start; i <= end; i++) {
      qrsLow = min(qrsLow, beat[i]);
      qrsHigh = max(qrsHigh, beat[i]);
    }
    if (height.abs() < minTShare * (qrsHigh - qrsLow)) return null;

    int? tEnd = areaMethod
        ? _areaEnd(beat, peak, height.sign, to, ms(areaWindowMs), ms(areaSearchMs))
        : _tangentEnd(beat, peak, height.sign, baseline, to, ms(steepSearchMs));
    if (tEnd == null || tEnd <= peak || tEnd >= beat.length) return null;
    return QtMeasurement(start, peak, tEnd, (tEnd - start) * 1000 / sampleRateHz, rrMs, height);
  }

  // the tangent method: the line through the steepest point of the falling part of T,
  // where it crosses the baseline
  static int? _tangentEnd(List<double> beat, int peak, double sign, double baseline, int to, int search) {
    double slope(int i) => (beat[i + 2] - beat[i - 2]) / 4;
    int steepest = -1;
    double steepestSlope = 0;
    for (int i = peak + 1; i <= min(to - 2, peak + search); i++) {
      double s = slope(i) * sign;   // < 0 = going back to the baseline
      if (s < steepestSlope) {
        steepestSlope = s;
        steepest = i;
      }
    }
    if (steepest < 0) return null;
    return (steepest + (baseline - beat[steepest]) / slope(steepest)).round();
  }

  // the area method (Zhang et al. 2006): for every point t after the T top, the area between the
  // signal and the level of t over the window before t; it is biggest where the T wave has just
  // ended (before: the wave is not over, after: the flat part only adds nothing). No baseline needed
  // 96 ms: the best on the QT Database (64-160 ms tried, tool/qt_validation.dart)
  static const double areaWindowMs = 96;
  static const double areaSearchMs = 250;
  static int? _areaEnd(List<double> beat, int peak, double sign, int to, int window, int search) {
    int best = -1;
    double bestArea = double.negativeInfinity;
    for (int t = peak + 1; t <= min(to, peak + search); t++) {
      double area = 0;
      for (int i = max(peak, t - window + 1); i <= t; i++) {
        area += (beat[i] - beat[t]) * sign;
      }
      if (area > bestArea) {
        bestArea = area;
        best = t;
      }
    }
    return best < 0 ? null : best;
  }
}

// the QT of a recording, as the app shows it:
//   the QRS start and end: measured on the median beat of the chart signal (the same numbers as
//   "the typical QRS width", QrsWidth), moved to the long median beat by their distance from R
//   the T end: on the long median beat (300 ms before R, up to 600 ms after) of the ZERO PHASE
//   filtered signal (see ZeroPhaseFilter: the live filters move the T wave)
class QtSummary {
  QtSummary._(this.beat, this.r, this.qrs, this.qt, {this.variableShape = false});

  final List<double> beat;   // the long median beat (mV), for the chart
  final int r;               // R in it
  final (int, int)? qrs;     // the QRS start / end in it, null = not measured
  final QtMeasurement? qt;   // null = no clear T wave (or no QRS)
  final bool variableShape;  // the beats differ too much (QrsWidth.minShapeAgreement): no QRS, no QT

  // regularBeats: e.g. QrsWidth.regularBeats, rrMs: the typical RR interval
  // null = fewer than 5 usable beats
  static QtSummary? analyze(List<double> chartSignal, List<double> measureSignal, List<int> regularBeats,
      double rrMs, int sampleRateHz, {double minTShare = QtInterval.minTShare}) {
    (List<double>, int)? chart = QrsWidth.medianBeat(chartSignal, regularBeats, sampleRateHz);
    (List<double>, int)? long = QrsWidth.medianBeat(measureSignal, regularBeats, sampleRateHz,
        beforeMs: QtInterval.beforeRMs, afterMs: QtInterval.afterRMs(rrMs));
    if (chart == null || long == null) return null;
    if (!QrsWidth.similarShapes(chartSignal, regularBeats, chart.$1, chart.$2, sampleRateHz)) {
      return QtSummary._(long.$1, long.$2, null, null, variableShape: true);
    }
    (int, int)? q = QrsWidth.measure(chart.$1, chart.$2, sampleRateHz);
    (int, int)? qrs = q == null ? null : (long.$2 + q.$1 - chart.$2, long.$2 + q.$2 - chart.$2);
    QtMeasurement? qt = qrs == null
        ? null
        : QtInterval.measure(long.$1, long.$2, qrs, rrMs, sampleRateHz, minTShare: minTShare);
    return QtSummary._(long.$1, long.$2, qrs, qt);
  }
}

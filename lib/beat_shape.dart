import 'dart:math';   // sqrt, max, min

// how similar one beat is to the typical beat of the recording (the median beat, QrsWidth)
//
// a beat that started in the ventricles (premature ventricular, PVC) spreads through the heart
// a different way: its QRS has a different shape (and is usually wider), even if it comes
// almost on time; a beat from the atria (normal or premature) has the same QRS as the others
//
// the measure: the correlation of the beat with the median beat, from 80 ms before R to
// 120 ms after R (the whole QRS), the best one when the beat is shifted up to +-20 ms
// (R is the highest |value|, in a strange beat it can be in another place of the QRS)
//   1 = the same shape, 0 = nothing in common, < 0 = upside down
// the correlation does not depend on the size, so the size is a second measure:
// the peak to peak height of the beat / of the median beat
class BeatShape {
  static const double beforeMs = 80;
  static const double afterMs = 120;
  static const double maxShiftMs = 20;

  // null = too close to the start / end of the recording or the template
  static double? correlation(List<double> x, int r, List<double> template, int templateR, int sampleRateHz) {
    int before = (beforeMs / 1000 * sampleRateHz).round();
    int after = (afterMs / 1000 * sampleRateHz).round();
    int shift = (maxShiftMs / 1000 * sampleRateHz).round();
    if (templateR - before < 0 || templateR + after >= template.length) return null;
    if (r - before - shift < 0 || r + after + shift >= x.length) return null;

    // the template part, without its mean
    int n = before + after + 1;
    List<double> t = [for (int i = -before; i <= after; i++) template[templateR + i]];
    double tMean = t.reduce((a, b) => a + b) / n;
    double tNorm = 0;
    for (int i = 0; i < n; i++) {
      t[i] -= tMean;
      tNorm += t[i] * t[i];
    }
    if (tNorm == 0) return null;

    double best = -1;
    for (int s = -shift; s <= shift; s++) {
      double mean = 0;
      for (int i = -before; i <= after; i++) {
        mean += x[r + s + i];
      }
      mean /= n;
      double dot = 0, norm = 0;
      for (int i = 0; i < n; i++) {
        double v = x[r + s - before + i] - mean;
        dot += v * t[i];
        norm += v * v;
      }
      if (norm == 0) continue;
      best = max(best, dot / sqrt(norm * tNorm));
    }
    return best;
  }

  // the height of the beat / the height of the median beat, in the same window (no shift)
  static double? heightRatio(List<double> x, int r, List<double> template, int templateR, int sampleRateHz) {
    int before = (beforeMs / 1000 * sampleRateHz).round();
    int after = (afterMs / 1000 * sampleRateHz).round();
    if (templateR - before < 0 || templateR + after >= template.length) return null;
    if (r - before < 0 || r + after >= x.length) return null;
    double height(List<double> v, int c) {
      double lo = v[c - before], hi = v[c - before];
      for (int i = c - before; i <= c + after; i++) {
        lo = min(lo, v[i]);
        hi = max(hi, v[i]);
      }
      return hi - lo;
    }

    double t = height(template, templateR);
    return t == 0 ? null : height(x, r) / t;
  }
}

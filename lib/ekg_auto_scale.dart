import 'ekg_buffer.dart';

// "Auto" zoom: picks ×1 / ×2 / ×4 / ×8 so the QRS of THIS person fills the chart nicely
// (the first real recordings had only ~0.3 mV QRS, at ×1 it was a few pixels high)
// only the zoom steps, no values in between: the scale text stays a round number,
// and a doctor-like reading of the squares still works
class EkgAutoScale {
  // mV per big square: ×1 (standard paper), ×2, ×4, ×8
  static const List<double> steps = [0.5, 0.25, 0.125, 0.0625];

  double _current = 0.25;   // the start before there is any signal (×2)
  double get current => _current;

  // how much of the half height (0 mV line to the edge) the peaks may take
  static const double _zoomOutAbove = 0.95;  // more than 95 %: the peaks almost hit the edge -> zoom out at once
  static const double _zoomOutTarget = 0.7;  // after zooming out the peaks take at most 70 %
  static const double _zoomInBelow = 0.7;    // zoom in only if the peaks take at most 70 % after it
  // zooming in doubles the height, so it happens only under 35 % now, zooming out only over 95 %:
  // the wide gap stops the scale from jumping back and forth at the border between two steps (hysteresis)

  // called by the chart on every repaint, halfHeightSquares = big squares from the 0 mV line to the edge
  double update(EkgBuffer buffer, int sampleRateHz, double halfHeightSquares) {
    double? peak = typicalPeak(buffer, sampleRateHz);
    if (peak != null) _current = choose(peak, halfHeightSquares, _current);
    return _current;
  }

  // the usual height of the beats in the buffer, in mV
  // the buffer is cut into 1 s pieces, the highest |value| of each piece, and the MEDIAN of those:
  // one or two artifacts (moving the cable, 10x the QRS) don't make the beats tiny,
  // and the jump of the filters at the start of a recording is ignored the same way
  // null = less than 1 s of signal, nothing to decide on yet
  static double? typicalPeak(EkgBuffer buffer, int sampleRateHz) {
    int pieces = buffer.length ~/ sampleRateHz;
    if (pieces == 0) return null;
    List<double> peaks = [];
    for (int p = 0; p < pieces; p++) {
      double peak = 0;
      for (int i = p * sampleRateHz; i < (p + 1) * sampleRateHz; i++) {
        double v = buffer[i].abs();
        if (v > peak) peak = v;
      }
      peaks.add(peak);
    }
    peaks.sort();
    return peaks[peaks.length ~/ 2];
  }

  // the step for this peak height, pure function (testable)
  static double choose(double peakMv, double halfHeightSquares, double current) {
    // how much of the half height the peaks take at a given step
    double fill(double mvPerSquare) => peakMv / (halfHeightSquares * mvPerSquare);

    if (fill(current) > _zoomOutAbove) {
      // too big: the most zoomed-in step where it fits comfortably, ×1 if nothing fits
      for (double step in steps.reversed) {   // reversed: ×8 first
        if (fill(step) <= _zoomOutTarget) return step;
      }
      return steps.first;
    }
    // small enough: zoom in as far as it still fits comfortably
    for (double step in steps.reversed) {
      if (step >= current) break;              // only steps more zoomed-in than now
      if (fill(step) <= _zoomInBelow) return step;
    }
    return current;
  }
}

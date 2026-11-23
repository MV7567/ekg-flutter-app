import 'biquad_filter.dart';
import 'spike_remover.dart';

// the same filters as the chart (0.5 Hz high-pass, 50 Hz notch, 40 Hz low-pass), but without
// the phase shift: the recording goes through them forwards and then backwards, the shifts of the
// two passes cancel out (like filtfilt in MATLAB / SciPy)
//
// why: a live filter can only look at the past, so it delays the slow waves differently than the
// fast ones; the 0.5 Hz high-pass bends the ST segment and moves the T wave by tens of ms. On the
// chart nobody sees it, but the QT interval is measured from the QRS start to the T end.
// a saved recording is known as a whole, so it can be filtered backwards too
// (the diagnostic ECG standards ask for 0.05 Hz, or 0.67 Hz with zero phase, for this reason)
class ZeroPhaseFilter {
  static List<double> apply(List<double> millivolts, double sampleRateHz) {
    SpikeRemover spikes = SpikeRemover();
    List<double> x = [for (double v in millivolts) spikes.process(v)];
    x = _pass(x, sampleRateHz);
    x = _pass(x.reversed.toList(), sampleRateHz);
    return x.reversed.toList();
  }

  // one pass through the filters, the high-pass primed with the first sample (no jump at the start)
  static List<double> _pass(List<double> x, double sampleRateHz) {
    if (x.isEmpty) return x;
    BiquadFilter highPass = BiquadFilter.highPass(frequencyHz: 0.5, sampleRateHz: sampleRateHz)..prime(x.first, 0);
    BiquadFilter notch = BiquadFilter.notch(frequencyHz: 50, sampleRateHz: sampleRateHz);
    BiquadFilter lowPass = BiquadFilter.lowPass(frequencyHz: 40, sampleRateHz: sampleRateHz);
    return [for (double v in x) lowPass.process(notch.process(highPass.process(v)))];
  }
}

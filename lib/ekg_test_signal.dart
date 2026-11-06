import 'dart:async';   // Timer
import 'dart:math';    // exp, sin, pi
import 'ekg_config.dart';

// fake ESP32 for testing without the board and electrodes (debug builds only, see ScannerScreen):
// makes the same 21-byte packets as the firmware, 25 per second,
// so the decoder, filters, chart, CSV and the Recordings screen all get tested, only BLE is skipped
//
// the signal: a simple EKG (P, QRS, T waves) at 72 beats per minute, plus what a real
// measurement has, so the display filter has something to remove:
// - DC offset -5 mV           -> removed by the 0.5 Hz high-pass
// - baseline wander 0.3 Hz    -> removed by the high-pass
// - 50 Hz mains hum           -> removed by the 50 Hz notch
class EkgTestSignal {
  EkgTestSignal(this.onPacket);

  // called with every packet, the same function that gets the BLE notifications
  final void Function(List<int> packet) onPacket;

  Timer? _timer;
  int _seq = 0;       // sequence number byte, 0..255
  int _sample = 0;    // number of the next sample, gives the time

  bool get isRunning => _timer != null;

  void start() {
    stop();
    _seq = 0;
    _sample = 0;
    // 10 samples at 250 Hz = 40 ms per packet
    _timer = Timer.periodic(
      const Duration(milliseconds: 1000 * samplesPerPacket ~/ sampleRateHz),
      (_) => onPacket(nextPacket()),
    );
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  // the next 10 samples as a packet, public so a test can call it without the timer
  List<int> nextPacket() {
    List<int> raw = [];
    for (int i = 0; i < samplesPerPacket; i++) {
      double t = _sample / sampleRateHz;
      raw.add(rawFromMillivolts(millivoltsAt(t)));
      _sample++;
    }
    List<int> packet = buildPacket(_seq, raw);
    _seq = (_seq + 1) & 0xFF;   // after 255 comes 0, like the firmware's byte
    return packet;
  }

  // ---- pure functions, testable ----

  static const double beatsPerMinute = 72;

  // the signal in mV at time t (seconds)
  static double millivoltsAt(double t) {
    return -5.0                              // DC offset of the electrodes
        + 0.3 * sin(2 * pi * 0.3 * t)        // baseline wander (breathing)
        + 0.05 * sin(2 * pi * 50 * t)        // mains hum
        + cleanEkgAt(t);
  }

  // only the heart beat, without the disturbances: a sum of bell curves (Gaussians),
  // one for each wave, position and width in seconds after the start of the beat
  static double cleanEkgAt(double t) {
    double beatLength = 60 / beatsPerMinute;   // 0.833 s
    double x = t % beatLength;                 // time inside the current beat
    return _wave(x, 0.15, 0.10, 0.025)         // P  (atria)
        + _wave(x, -0.10, 0.20, 0.010)         // Q
        + _wave(x, 1.20, 0.23, 0.010)          // R  (the big spike)
        + _wave(x, -0.25, 0.26, 0.010)         // S
        + _wave(x, 0.30, 0.45, 0.040);         // T  (ventricles recover)
  }

  // bell curve: height mv at time center, sigma = how wide
  static double _wave(double x, double mv, double center, double sigma) =>
      mv * exp(-pow(x - center, 2) / (2 * sigma * sigma));

  // mV -> ADC value, limited to int16 like the real ADS1194
  static int rawFromMillivolts(double mv) =>
      (mv / millivoltsPerLsb).round().clamp(-32768, 32767);

  // sequence byte + every sample as 2 bytes, high byte first (big-endian), like the firmware
  static List<int> buildPacket(int seq, List<int> rawValues) {
    List<int> packet = [seq & 0xFF];
    for (int value in rawValues) {
      packet.add((value >> 8) & 0xFF);   // high byte (for negative values the sign bits)
      packet.add(value & 0xFF);          // low byte
    }
    return packet;
  }
}

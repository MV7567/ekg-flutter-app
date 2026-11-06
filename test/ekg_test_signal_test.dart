import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/ekg_config.dart';
import 'package:ecg_ble_app/ekg_packet_decoder.dart';
import 'package:ecg_ble_app/ekg_test_signal.dart';

void main() {
  test('packets look like the firmware ones: the decoder reads them back', () {
    EkgTestSignal signal = EkgTestSignal((_) {});
    EkgPacketDecoder decoder = EkgPacketDecoder();
    for (int i = 0; i < 300; i++) {   // 300 packets, the sequence byte wraps after 255
      List<int> packet = signal.nextPacket();
      expect(packet.length, packetLength);
      expect(decoder.decode(packet), isNotNull);
    }
    expect(decoder.lostPackets, 0);
    expect(decoder.badPackets, 0);
    expect(decoder.sampleCount, 300 * samplesPerPacket);
  });
  // the generator makes 300 packets, the decoder reads it with no errors

  test('negative values survive the big-endian bytes', () {
    List<int> packet = EkgTestSignal.buildPacket(7, [-1475, 1000, -1, 0, 32767, -32768, 1, 2, 3, 4]);
    EkgPacket? decoded = EkgPacketDecoder().decode(packet);
    expect(decoded!.rawValues, [-1475, 1000, -1, 0, 32767, -32768, 1, 2, 3, 4]);
  });
  // edge values

  test('R wave is the highest point of a beat, about 1.2 mV', () {
    double r = EkgTestSignal.cleanEkgAt(0.23);
    expect(r, closeTo(1.2, 0.05));
    for (double t = 0; t < 0.83; t += 0.004) {
      expect(EkgTestSignal.cleanEkgAt(t), lessThanOrEqualTo(r));
    }
  });
  // R - highest point 

  test('raw value is limited to int16 like the ADS1194', () {
    expect(EkgTestSignal.rawFromMillivolts(1000), 32767);
    expect(EkgTestSignal.rawFromMillivolts(-1000), -32768);
  });
  // raw value turned into int16
}

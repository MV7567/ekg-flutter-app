import 'package:flutter_test/flutter_test.dart';
import 'package:ecg_ble_app/ekg_config.dart';
import 'package:ecg_ble_app/ekg_packet_decoder.dart';

// builds a packet like the ESP32 does: sequence number + 10 x int16, high byte first
List<int> makePacket(int seq, List<int> values) {
  List<int> bytes = [seq];
  for (int v in values) {
    bytes.add((v >> 8) & 0xFF);
    bytes.add(v & 0xFF);
  }
  return bytes;
}

List<int> tenTimes(int v) => List.filled(samplesPerPacket, v);

void main() {
  test('decodes positive and negative values', () {
    final decoder = EkgPacketDecoder();
    final packet = decoder.decode(
        makePacket(0, [0, 1, -1, 32767, -32768, 1000, -1000, 256, -256, 12345]))!;

    expect(packet.rawValues, [0, 1, -1, 32767, -32768, 1000, -1000, 256, -256, 12345]);
    expect(packet.firstSampleIndex, 0);
    expect(decoder.sampleCount, 10);
  });

  test('packets in order: sample numbers continue, nothing lost', () {
    final decoder = EkgPacketDecoder();
    decoder.decode(makePacket(7, tenTimes(0)));   // first packet may have any number
    final second = decoder.decode(makePacket(8, tenTimes(0)))!;

    expect(second.firstSampleIndex, 10);
    expect(decoder.lostPackets, 0);
  });

  test('gap in sequence numbers: lost packets counted, time axis jumps over the gap', () {
    final decoder = EkgPacketDecoder();
    decoder.decode(makePacket(10, tenTimes(0)));
    final afterGap = decoder.decode(makePacket(13, tenTimes(0)))!;   // 11 and 12 lost

    expect(decoder.lostPackets, 2);
    expect(afterGap.firstSampleIndex, 30);   // 10 (packet 10) + 2 x 10 skipped
    expect(decoder.sampleCount, 40);
  });

  test('wrap from 255 to 0 is not a gap', () {
    final decoder = EkgPacketDecoder();
    decoder.decode(makePacket(255, tenTimes(0)));
    decoder.decode(makePacket(0, tenTimes(0)));
    expect(decoder.lostPackets, 0);

    decoder.decode(makePacket(2, tenTimes(0)));   // 1 lost after the wrap
    expect(decoder.lostPackets, 1);
  });

  test('gap over the wrap: 254, 255, 0 lost between 253 and 1', () {
    final decoder = EkgPacketDecoder();
    decoder.decode(makePacket(253, tenTimes(0)));
    final afterGap = decoder.decode(makePacket(1, tenTimes(0)))!;

    expect(decoder.lostPackets, 3);
    expect(afterGap.firstSampleIndex, 40);   // 10 (packet 253) + 3 x 10 skipped
  });

  test('duplicate packet is skipped, not counted as 255 lost', () {
    final decoder = EkgPacketDecoder();
    decoder.decode(makePacket(5, tenTimes(0)));
    expect(decoder.decode(makePacket(5, tenTimes(0))), isNull);   // the same packet again

    expect(decoder.duplicatePackets, 1);
    expect(decoder.lostPackets, 0);
    expect(decoder.sampleCount, 10);   // no fake gap

    final next = decoder.decode(makePacket(6, tenTimes(0)))!;   // the next one is still expected
    expect(next.firstSampleIndex, 10);
    expect(decoder.lostPackets, 0);
  });

  test('packet with a wrong length is rejected and counted', () {
    final decoder = EkgPacketDecoder();
    final cut = makePacket(0, tenTimes(5)).sublist(0, 20);   // cut by a too small MTU

    expect(decoder.decode(cut), isNull);
    expect(decoder.badPackets, 1);
    expect(decoder.lastBadLength, 20);
    expect(decoder.sampleCount, 0);
  });

  test('rejected packet is also counted as lost, the time axis stays correct', () {
    final decoder = EkgPacketDecoder();
    decoder.decode(makePacket(0, tenTimes(0)));
    decoder.decode(makePacket(1, tenTimes(0)).sublist(0, 20));   // packet 1 cut, rejected
    final next = decoder.decode(makePacket(2, tenTimes(0)))!;

    expect(decoder.badPackets, 1);
    expect(decoder.lostPackets, 1);       // packet 1 is missing in the data
    expect(next.firstSampleIndex, 20);    // its 10 samples are skipped, not shifted
  });

  test('reset starts a new recording from zero', () {
    final decoder = EkgPacketDecoder();
    decoder.decode(makePacket(0, tenTimes(0)));
    decoder.decode(makePacket(5, tenTimes(0)));
    decoder.reset();

    final packet = decoder.decode(makePacket(42, tenTimes(0)))!;
    expect(packet.firstSampleIndex, 0);
    expect(decoder.lostPackets, 0);
  });
}

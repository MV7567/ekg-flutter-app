import 'ekg_config.dart'; // no flutter or ble needed

// samples from one BLE packet
class EkgPacket {
  EkgPacket(this.firstSampleIndex, this.rawValues); // constructor 

  // number of the first sample in the whole recording (the others follow one by one)
  final int firstSampleIndex;

  // ADC values as signed 16-bit numbers, multiply by millivoltsPerLsb to get mV
  final List<int> rawValues;
}

// turns the bytes of the BLE packets into samples and keeps track of lost packets
// packet: byte 0 = sequence number (0..255), then 10 samples x 2 bytes (int16, high byte first)
// no Flutter / BLE code here, so it can be tested without a phone
class EkgPacketDecoder {
  int _sampleIndex = 0;   // number of the next sample in the recording
  int? _expectedSeq;      // sequence number of the next packet, null before the first packet
  int _lostPackets = 0;
  int _badPackets = 0;
  int _lastBadLength = 0;
  int _duplicatePackets = 0;

  // getters cause private fields

  // all samples so far, including the skipped ones of lost packets (= recording length)
  int get sampleCount => _sampleIndex;

  // packets that never arrived (detected by gaps in the sequence numbers)
  // = packets missing in the file, so a rejected packet (badPackets) is counted here too,
  // because its sequence number is skipped
  // the sequence number has only 8 bits: a gap longer than 255 packets (10.2 s) would be
  // counted wrong (e.g. 300 as 44), in practice Android drops the connection much earlier
  int get lostPackets => _lostPackets;

  // packets that came twice (should not happen with BLE), skipped
  int get duplicatePackets => _duplicatePackets;

  // packets with a wrong length (e.g. cut to 20 bytes by a too small MTU)
  int get badPackets => _badPackets;
  int get lastBadLength => _lastBadLength;

  // returns the samples of the packet, or null if the packet is skipped (wrong length or duplicate)
  EkgPacket? decode(List<int> data) {
    if (data.length != packetLength) {
      _badPackets++;
      _lastBadLength = data.length;
      return null;
    }

    // byte 0 = packet number, a gap means packets were lost on the way
    int seq = data[0];
    if (_expectedSeq != null && seq != _expectedSeq) {  // the gap is when we know the expected number and a different one came
      int lost = (seq - _expectedSeq!) & 0xFF;   // & 0xFF handles the wrap from 255 to 0
      // leaves the 8 youngest bits, zeroes the rest, because the counter in esp32 is uint8_t an dafter 255 it goes back down to 0

      // 255 "lost" = the same number as the previous packet came again (expected - 1),
      // counting it as a gap would add 10 s of fake gap to the file, so the packet is skipped
      // (_expectedSeq stays the same, the next packet is still the expected one)
      if (lost == 255) {
        _duplicatePackets++;
        return null;
      }

      _lostPackets += lost;
      _sampleIndex += lost * samplesPerPacket;   // keep the time axis correct
    } // the gap is recognized during analysis
    _expectedSeq = (seq + 1) & 0xFF;  // next expected number, after 255 we expect 0 not 256

    List<int> rawValues = [];
    for (int i = 1; i < data.length; i += 2) {    // loop starts from 1 because 0 is the packet number and increments by 2 beause each sample is 2 bytes
      // combine the two bytes into a single 16-bit integer
      int value = (data[i] << 8) | data[i + 1];   // firmware sends big endian first, shift 8 bits left, then OR with the next byte

      // 0x8000..0xFFFF are negative numbers in two's complement
      if (value > 32767) {
        value -= 65536;
      }
      // 0x0000 to 0x7FFF (0 to 32767) are positive numbers, no change
      // 0x8000 to 0xFFFF (32768 to 65535) are negative, so we subtract 65536 to get the correct negative value
      rawValues.add(value);
    }
    // after sticking the bytes together dart sees a normal number because int has 64 bits, and doesnt know it was meant to be a 16-bit signed int so we have to do the conversion manually

    EkgPacket packet = EkgPacket(_sampleIndex, rawValues);
    _sampleIndex += samplesPerPacket;
    return packet;
  }
  // packet gets the actual number, then the counter increments by 10 for the next packet, 

  // start from zero, for every new recording
  void reset() {
    _sampleIndex = 0;
    _expectedSeq = null;  // the first packet of a new recording can have any sequence number.
    _lostPackets = 0;
    _badPackets = 0;
    _lastBadLength = 0;
    _duplicatePackets = 0;
  }
}

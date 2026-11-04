import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// shared settings, must match the ESP32 firmware

// BLE service and characteristic UUIDs
final Guid ekgServiceUuid = Guid("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
final Guid ekgCharacteristicUuid = Guid("beb5483e-36e1-4688-b7f5-ea07361b26a8");
final Guid ekgControlCharacteristicUuid = Guid("beb5483f-36e1-4688-b7f5-ea07361b26a8");
// UUIDs are unique 128-bit identifiers. BLE devices have services, which have characteristics, meaning variables that can be read, written or subscribed
// ekg service, the scanner filters devices
// data characteristic, ESP32 sends packets through it
// control characteristic, app sends commands to the ESP32 through it (start/stop sampling)

// commands written to the control characteristic
const int controlStop = 0x00;
const int controlStart = 0x01;
// byte written to the control characteristic, hex values, the same values are used in the firmware as CONTROL_STOP and CONTROL_START

// one BLE packet = 1 byte sequence number (0..255) + 10 samples x 2 bytes (int16, high byte first)
const int samplesPerPacket = 10;
const int packetLength = 1 + samplesPerPacket * 2;
// a packet has 1 byte sequence number and 10 samples, each 2 bytes, together 21 bytes. 
// packetLength is calculated so if the samples number is changed the length will also change.

// ADS1194 CONFIG1 = 0x05 -> 250 samples per second
const int sampleRateHz = 250;

// 1 LSB = VREF / (2^15 - 1) / gain = 2.4 V / 32767 / 12 (CH1SET = 0x60 -> gain 12)
// pgaGain MUST be the same as the gain set in the firmware, otherwise the mV values are wrong
const double vref = 2.4;
const int pgaGain = 12;
const double millivoltsPerLsb = vref / 32767 / pgaGain * 1000; // ~0.0061 mV
// converting the raw sample into mV
// vref is the reference voltage of the ADC, 2.4V
// / pgaGain divides by the gain of the amplifier, 12*
// LSB, the smallest step of the ADC

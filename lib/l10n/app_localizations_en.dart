// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageName => 'English';

  @override
  String get commonCancel => 'CANCEL';

  @override
  String get commonShare => 'Share';

  @override
  String get commonDelete => 'Delete';

  @override
  String get appTitle => 'EKG';

  @override
  String get homeSubtitle => 'ESP32 + ADS1194 over Bluetooth';

  @override
  String get homeConnect => 'Connect to EKG device';

  @override
  String get homeRecordings => 'Recordings';

  @override
  String get homeHowToMeasure => 'How to measure';

  @override
  String get homeSettings => 'Settings';

  @override
  String get homeTestSignal => 'Test signal (debug)';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsLikePhone => 'Like the phone';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSystem => 'System';

  @override
  String get settingsColors => 'Colors';

  @override
  String get paletteRed => 'Red';

  @override
  String get paletteBlue => 'Blue';

  @override
  String get paletteTeal => 'Teal';

  @override
  String get paletteGreen => 'Green';

  @override
  String get palettePurple => 'Purple';

  @override
  String get paletteOrange => 'Orange';

  @override
  String get scannerTitle => 'Search for EKG Devices';

  @override
  String get scannerPermissionNeeded =>
      'The app needs the Bluetooth permission to find the EKG device';

  @override
  String get scannerOpenSettings => 'SETTINGS';

  @override
  String scannerScanFailed(String error) {
    return 'Scan failed, check if Bluetooth is on: $error';
  }

  @override
  String get scannerSearching => 'Searching...';

  @override
  String get scannerNothingFound =>
      'No EKG device found.\nCheck if the ESP32 is powered on and try again.';

  @override
  String get scannerHint =>
      'Press the search button to find the ESP32_EKG device.';

  @override
  String get scannerUnknownDevice => 'Unknown Device';

  @override
  String get scannerConnect => 'CONNECT';

  @override
  String get deviceUnknown => 'Unknown';

  @override
  String get deviceConnectionLost => 'Connection lost, recording saved';

  @override
  String get deviceCouldNotConnect =>
      'Could not connect, is the ESP32 powered on and nearby?';

  @override
  String get deviceServiceNotFound =>
      'EKG service not found, is the right firmware uploaded?';

  @override
  String get deviceServiceReadError =>
      'Could not read the EKG service, try to reconnect';

  @override
  String get deviceFileError => 'Could not create the data file';

  @override
  String get deviceStartError => 'Could not send the start command';

  @override
  String get deviceIncomplete =>
      'Recording may be incomplete, the file could not be written';

  @override
  String deviceTimedFinished(String length) {
    return 'Recording finished ($length), saved';
  }

  @override
  String get deviceLeaveTitle => 'Stop the recording?';

  @override
  String get deviceLeaveContent => 'The recording will be stopped and saved.';

  @override
  String get deviceStopAndLeave => 'STOP AND LEAVE';

  @override
  String get deviceStateTestSignal => 'TEST SIGNAL';

  @override
  String get deviceStateConnecting => 'CONNECTING...';

  @override
  String get deviceStateConnected => 'CONNECTED';

  @override
  String get deviceStateDisconnected => 'DISCONNECTED';

  @override
  String get deviceSearchingService => 'Searching for the EKG service...';

  @override
  String get deviceLength => 'Length:';

  @override
  String get deviceLengthManual => 'Manual (until STOP)';

  @override
  String get deviceWhereElectrodes => 'Where to put the electrodes?';

  @override
  String get deviceStart => 'START';

  @override
  String get deviceStop => 'STOP';

  @override
  String deviceOfLength(String length) {
    return 'of $length';
  }

  @override
  String deviceSamples(int count) {
    return 'Samples: $count';
  }

  @override
  String deviceLostPackets(int count) {
    return 'Lost packets: $count';
  }

  @override
  String deviceRejectedPackets(
    int count,
    int length,
    int expected,
    String mtu,
  ) {
    return 'Rejected packets: $count (length $length instead of $expected, MTU $mtu)';
  }

  @override
  String get deviceSavingTo => 'Saving to:';

  @override
  String get deviceLastSaved => 'Last recording saved in:';

  @override
  String get deviceReconnect => 'RECONNECT';

  @override
  String get recordingsUnknownDate => 'Unknown date';

  @override
  String recordingsReadError(String error) {
    return 'Cannot read recordings:\n$error';
  }

  @override
  String get recordingsEmpty =>
      'No recordings yet.\nStart a recording on the device screen.';

  @override
  String viewOpenError(String error) {
    return 'Cannot open the recording:\n$error';
  }

  @override
  String get viewNoSamples => 'The recording has no samples.';

  @override
  String shareSubject(String date) {
    return 'EKG recording $date';
  }

  @override
  String shareError(String error) {
    return 'Cannot share: $error';
  }

  @override
  String get deleteTitle => 'Delete recording?';

  @override
  String get deleteWarning =>
      'The file is deleted from the phone, this cannot be undone.';

  @override
  String get deleteButton => 'DELETE';

  @override
  String deleteError(String error) {
    return 'Cannot delete: $error';
  }

  @override
  String get fullscreenEnter => 'Full screen';

  @override
  String get fullscreenExit => 'Exit full screen';

  @override
  String heartRate(String value) {
    return '$value bpm';
  }

  @override
  String viewAverageBpm(String value) {
    return 'average $value bpm';
  }

  @override
  String chartScale(String seconds, String millivolts) {
    return '1 square: $seconds s × $millivolts mV';
  }

  @override
  String get instrSafetyTitle => 'Safety';

  @override
  String get instrSafety1 =>
      'This is a student project, not a medical device. Do not use it for diagnosis.';

  @override
  String get instrSafety2 =>
      'Power the board from a battery or a laptop running on battery, never from a wall charger while the electrodes are on the body.';

  @override
  String get instrSafety3 =>
      'Stop if the skin under an electrode itches or burns.';

  @override
  String get instrElectrodesTitle => '1. Electrodes';

  @override
  String get instrElectrodesIntro =>
      'Three electrodes, the cable labels say which one is which:';

  @override
  String get instrRightArm => 'Right arm';

  @override
  String get instrRightArmWhere => 'right wrist or below the right collarbone';

  @override
  String get instrLeftArm => 'Left arm';

  @override
  String get instrLeftArmWhere => 'left wrist or below the left collarbone';

  @override
  String get instrLeftLeg => 'Left leg';

  @override
  String get instrLeftLegWhere =>
      'left side of the belly, below the heart, or the left ankle';

  @override
  String get instrFrontView =>
      'Seen from the front: the right arm of the person is on the LEFT of the picture.';

  @override
  String get instrSkinTitle => '2. Skin';

  @override
  String get instrSkin1 =>
      'Clean and dry skin, an alcohol wipe helps. No cream or lotion.';

  @override
  String get instrSkin2 =>
      'Fresh gel electrodes, an old dry one gives a noisy line.';

  @override
  String get instrSkin3 =>
      'Not on hair, bone or a tense muscle. Press the edges down well.';

  @override
  String get instrDuringTitle => '3. During the measurement';

  @override
  String get instrDuring1 =>
      'Sit or lie down, relax, arms resting. Do not talk or move.';

  @override
  String get instrDuring2 =>
      'Keep the phone, chargers and power cables away from the cables (50 Hz hum).';

  @override
  String get instrDuring3 =>
      'Wait about 10 s after pressing START, the line needs a moment to settle.';

  @override
  String get instrDuring4 =>
      'Spikes pointing DOWN usually mean RA and LA are swapped.';

  @override
  String get instrLengthTitle => '4. How long to record';

  @override
  String get instrLength1 =>
      '10 s: a quick look, the same length as a hospital 12-lead ECG.';

  @override
  String get instrLength2 =>
      '30 s – 1 min: recommended, enough beats to see the rhythm.';

  @override
  String get instrLength3 =>
      '5 min: for heart rate variability (HRV) analysis.';

  @override
  String get instrLength4 =>
      'Choose the length next to the START button, the recording stops by itself.';
}

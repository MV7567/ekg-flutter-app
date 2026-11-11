import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pl'),
  ];

  /// Name of this language, written in this language, shown in the language list
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageName;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'CANCEL'**
  String get commonCancel;

  /// No description provided for @commonShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'EKG'**
  String get appTitle;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'ESP32 + ADS1194 over Bluetooth'**
  String get homeSubtitle;

  /// No description provided for @homeConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect to EKG device'**
  String get homeConnect;

  /// No description provided for @homeRecordings.
  ///
  /// In en, this message translates to:
  /// **'Recordings'**
  String get homeRecordings;

  /// No description provided for @homeHowToMeasure.
  ///
  /// In en, this message translates to:
  /// **'How to measure'**
  String get homeHowToMeasure;

  /// No description provided for @homeSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get homeSettings;

  /// No description provided for @homeTestSignal.
  ///
  /// In en, this message translates to:
  /// **'Test signal (debug)'**
  String get homeTestSignal;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// No description provided for @settingsLikePhone.
  ///
  /// In en, this message translates to:
  /// **'Like the phone'**
  String get settingsLikePhone;

  /// No description provided for @settingsThemeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsColors.
  ///
  /// In en, this message translates to:
  /// **'Colors'**
  String get settingsColors;

  /// No description provided for @settingsChartMatchesPalette.
  ///
  /// In en, this message translates to:
  /// **'EKG chart in palette colors'**
  String get settingsChartMatchesPalette;

  /// No description provided for @settingsChartMatchesPaletteHint.
  ///
  /// In en, this message translates to:
  /// **'Off: pink paper (light) / green monitor (dark)'**
  String get settingsChartMatchesPaletteHint;

  /// No description provided for @paletteRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get paletteRed;

  /// No description provided for @paletteBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get paletteBlue;

  /// No description provided for @paletteTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get paletteTeal;

  /// No description provided for @paletteGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get paletteGreen;

  /// No description provided for @palettePurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get palettePurple;

  /// No description provided for @paletteOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get paletteOrange;

  /// No description provided for @scannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Search for EKG Devices'**
  String get scannerTitle;

  /// No description provided for @scannerPermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'The app needs the Bluetooth permission to find the EKG device'**
  String get scannerPermissionNeeded;

  /// No description provided for @scannerOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get scannerOpenSettings;

  /// No description provided for @scannerScanFailed.
  ///
  /// In en, this message translates to:
  /// **'Scan failed, check if Bluetooth is on: {error}'**
  String scannerScanFailed(String error);

  /// No description provided for @scannerSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching...'**
  String get scannerSearching;

  /// No description provided for @scannerNothingFound.
  ///
  /// In en, this message translates to:
  /// **'No EKG device found.\nCheck if the ESP32 is powered on and try again.'**
  String get scannerNothingFound;

  /// No description provided for @scannerHint.
  ///
  /// In en, this message translates to:
  /// **'Press the search button to find the ESP32_EKG device.'**
  String get scannerHint;

  /// No description provided for @scannerUnknownDevice.
  ///
  /// In en, this message translates to:
  /// **'Unknown Device'**
  String get scannerUnknownDevice;

  /// No description provided for @scannerConnect.
  ///
  /// In en, this message translates to:
  /// **'CONNECT'**
  String get scannerConnect;

  /// No description provided for @deviceUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get deviceUnknown;

  /// No description provided for @deviceConnectionLost.
  ///
  /// In en, this message translates to:
  /// **'Connection lost, recording saved'**
  String get deviceConnectionLost;

  /// No description provided for @deviceCouldNotConnect.
  ///
  /// In en, this message translates to:
  /// **'Could not connect, is the ESP32 powered on and nearby?'**
  String get deviceCouldNotConnect;

  /// No description provided for @deviceServiceNotFound.
  ///
  /// In en, this message translates to:
  /// **'EKG service not found, is the right firmware uploaded?'**
  String get deviceServiceNotFound;

  /// No description provided for @deviceServiceReadError.
  ///
  /// In en, this message translates to:
  /// **'Could not read the EKG service, try to reconnect'**
  String get deviceServiceReadError;

  /// No description provided for @deviceFileError.
  ///
  /// In en, this message translates to:
  /// **'Could not create the data file'**
  String get deviceFileError;

  /// No description provided for @deviceStartError.
  ///
  /// In en, this message translates to:
  /// **'Could not send the start command'**
  String get deviceStartError;

  /// No description provided for @deviceIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Recording may be incomplete, the file could not be written'**
  String get deviceIncomplete;

  /// No description provided for @deviceTimedFinished.
  ///
  /// In en, this message translates to:
  /// **'Recording finished ({length}), saved'**
  String deviceTimedFinished(String length);

  /// No description provided for @deviceLeaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Stop the recording?'**
  String get deviceLeaveTitle;

  /// No description provided for @deviceLeaveContent.
  ///
  /// In en, this message translates to:
  /// **'The recording will be stopped and saved.'**
  String get deviceLeaveContent;

  /// No description provided for @deviceStopAndLeave.
  ///
  /// In en, this message translates to:
  /// **'STOP AND LEAVE'**
  String get deviceStopAndLeave;

  /// No description provided for @deviceStateTestSignal.
  ///
  /// In en, this message translates to:
  /// **'TEST SIGNAL'**
  String get deviceStateTestSignal;

  /// No description provided for @deviceStateConnecting.
  ///
  /// In en, this message translates to:
  /// **'CONNECTING...'**
  String get deviceStateConnecting;

  /// No description provided for @deviceStateConnected.
  ///
  /// In en, this message translates to:
  /// **'CONNECTED'**
  String get deviceStateConnected;

  /// No description provided for @deviceStateDisconnected.
  ///
  /// In en, this message translates to:
  /// **'DISCONNECTED'**
  String get deviceStateDisconnected;

  /// No description provided for @deviceSearchingService.
  ///
  /// In en, this message translates to:
  /// **'Searching for the EKG service...'**
  String get deviceSearchingService;

  /// No description provided for @deviceLength.
  ///
  /// In en, this message translates to:
  /// **'Length:'**
  String get deviceLength;

  /// No description provided for @deviceLengthManual.
  ///
  /// In en, this message translates to:
  /// **'Manual (until STOP)'**
  String get deviceLengthManual;

  /// No description provided for @deviceWhereElectrodes.
  ///
  /// In en, this message translates to:
  /// **'Where to put the electrodes?'**
  String get deviceWhereElectrodes;

  /// No description provided for @deviceStart.
  ///
  /// In en, this message translates to:
  /// **'START'**
  String get deviceStart;

  /// No description provided for @deviceStop.
  ///
  /// In en, this message translates to:
  /// **'STOP'**
  String get deviceStop;

  /// No description provided for @deviceOfLength.
  ///
  /// In en, this message translates to:
  /// **'of {length}'**
  String deviceOfLength(String length);

  /// No description provided for @deviceSamples.
  ///
  /// In en, this message translates to:
  /// **'Samples: {count}'**
  String deviceSamples(int count);

  /// No description provided for @deviceLostPackets.
  ///
  /// In en, this message translates to:
  /// **'Lost packets: {count}'**
  String deviceLostPackets(int count);

  /// No description provided for @deviceRejectedPackets.
  ///
  /// In en, this message translates to:
  /// **'Rejected packets: {count} (length {length} instead of {expected}, MTU {mtu})'**
  String deviceRejectedPackets(int count, int length, int expected, String mtu);

  /// No description provided for @deviceSavingTo.
  ///
  /// In en, this message translates to:
  /// **'Saving to:'**
  String get deviceSavingTo;

  /// No description provided for @deviceLastSaved.
  ///
  /// In en, this message translates to:
  /// **'Last recording saved in:'**
  String get deviceLastSaved;

  /// No description provided for @deviceReconnect.
  ///
  /// In en, this message translates to:
  /// **'RECONNECT'**
  String get deviceReconnect;

  /// No description provided for @recordingsUnknownDate.
  ///
  /// In en, this message translates to:
  /// **'Unknown date'**
  String get recordingsUnknownDate;

  /// No description provided for @recordingsReadError.
  ///
  /// In en, this message translates to:
  /// **'Cannot read recordings:\n{error}'**
  String recordingsReadError(String error);

  /// No description provided for @recordingsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No recordings yet.\nStart a recording on the device screen.'**
  String get recordingsEmpty;

  /// No description provided for @viewOpenError.
  ///
  /// In en, this message translates to:
  /// **'Cannot open the recording:\n{error}'**
  String viewOpenError(String error);

  /// No description provided for @viewNoSamples.
  ///
  /// In en, this message translates to:
  /// **'The recording has no samples.'**
  String get viewNoSamples;

  /// E-mail subject when a recording is shared
  ///
  /// In en, this message translates to:
  /// **'EKG recording {date}'**
  String shareSubject(String date);

  /// No description provided for @shareError.
  ///
  /// In en, this message translates to:
  /// **'Cannot share: {error}'**
  String shareError(String error);

  /// No description provided for @deleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete recording?'**
  String get deleteTitle;

  /// No description provided for @deleteWarning.
  ///
  /// In en, this message translates to:
  /// **'The file is deleted from the phone, this cannot be undone.'**
  String get deleteWarning;

  /// No description provided for @deleteButton.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteButton;

  /// No description provided for @deleteError.
  ///
  /// In en, this message translates to:
  /// **'Cannot delete: {error}'**
  String deleteError(String error);

  /// No description provided for @fullscreenEnter.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get fullscreenEnter;

  /// No description provided for @fullscreenExit.
  ///
  /// In en, this message translates to:
  /// **'Exit full screen'**
  String get fullscreenExit;

  /// Heart rate, value is a number or -- when not known yet
  ///
  /// In en, this message translates to:
  /// **'{value} bpm'**
  String heartRate(String value);

  /// No description provided for @qualityChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking the signal…'**
  String get qualityChecking;

  /// No description provided for @qualityGood.
  ///
  /// In en, this message translates to:
  /// **'Good signal'**
  String get qualityGood;

  /// No description provided for @qualityNoisy.
  ///
  /// In en, this message translates to:
  /// **'Noisy signal – sit still, relax your muscles, press the electrodes'**
  String get qualityNoisy;

  /// No description provided for @qualityNoBeats.
  ///
  /// In en, this message translates to:
  /// **'No heart beats visible – check where the electrodes are'**
  String get qualityNoBeats;

  /// No description provided for @qualityFlat.
  ///
  /// In en, this message translates to:
  /// **'No signal – is an electrode or cable disconnected?'**
  String get qualityFlat;

  /// No description provided for @qualityElectrodeOff.
  ///
  /// In en, this message translates to:
  /// **'Signal out of range – an electrode is off or loose'**
  String get qualityElectrodeOff;

  /// Average heart rate of the whole recording
  ///
  /// In en, this message translates to:
  /// **'average {value} bpm'**
  String viewAverageBpm(String value);

  /// Scale of the EKG paper, top left of the chart
  ///
  /// In en, this message translates to:
  /// **'1 square: {seconds} s × {millivolts} mV'**
  String chartScale(String seconds, String millivolts);

  /// No description provided for @instrSafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Safety'**
  String get instrSafetyTitle;

  /// No description provided for @instrSafety1.
  ///
  /// In en, this message translates to:
  /// **'This is a student project, not a medical device. Do not use it for diagnosis.'**
  String get instrSafety1;

  /// No description provided for @instrSafety2.
  ///
  /// In en, this message translates to:
  /// **'Power the board from a battery or a laptop running on battery, never from a wall charger while the electrodes are on the body.'**
  String get instrSafety2;

  /// No description provided for @instrSafety3.
  ///
  /// In en, this message translates to:
  /// **'Stop if the skin under an electrode itches or burns.'**
  String get instrSafety3;

  /// No description provided for @instrElectrodesTitle.
  ///
  /// In en, this message translates to:
  /// **'1. Electrodes'**
  String get instrElectrodesTitle;

  /// No description provided for @instrElectrodesIntro.
  ///
  /// In en, this message translates to:
  /// **'Three electrodes, the cable labels say which one is which:'**
  String get instrElectrodesIntro;

  /// No description provided for @instrRightArm.
  ///
  /// In en, this message translates to:
  /// **'Right arm'**
  String get instrRightArm;

  /// No description provided for @instrRightArmWhere.
  ///
  /// In en, this message translates to:
  /// **'right wrist or below the right collarbone'**
  String get instrRightArmWhere;

  /// No description provided for @instrLeftArm.
  ///
  /// In en, this message translates to:
  /// **'Left arm'**
  String get instrLeftArm;

  /// No description provided for @instrLeftArmWhere.
  ///
  /// In en, this message translates to:
  /// **'left wrist or below the left collarbone'**
  String get instrLeftArmWhere;

  /// No description provided for @instrLeftLeg.
  ///
  /// In en, this message translates to:
  /// **'Left leg'**
  String get instrLeftLeg;

  /// No description provided for @instrLeftLegWhere.
  ///
  /// In en, this message translates to:
  /// **'left side of the belly, below the heart, or the left ankle'**
  String get instrLeftLegWhere;

  /// No description provided for @instrFrontView.
  ///
  /// In en, this message translates to:
  /// **'Seen from the front: the right arm of the person is on the LEFT of the picture.'**
  String get instrFrontView;

  /// No description provided for @instrSkinTitle.
  ///
  /// In en, this message translates to:
  /// **'2. Skin'**
  String get instrSkinTitle;

  /// No description provided for @instrSkin1.
  ///
  /// In en, this message translates to:
  /// **'Clean and dry skin, an alcohol wipe helps. No cream or lotion.'**
  String get instrSkin1;

  /// No description provided for @instrSkin2.
  ///
  /// In en, this message translates to:
  /// **'Fresh gel electrodes, an old dry one gives a noisy line.'**
  String get instrSkin2;

  /// No description provided for @instrSkin3.
  ///
  /// In en, this message translates to:
  /// **'Not on hair, bone or a tense muscle. Press the edges down well.'**
  String get instrSkin3;

  /// No description provided for @instrDuringTitle.
  ///
  /// In en, this message translates to:
  /// **'3. During the measurement'**
  String get instrDuringTitle;

  /// No description provided for @instrDuring1.
  ///
  /// In en, this message translates to:
  /// **'Sit or lie down, relax, arms resting. Do not talk or move.'**
  String get instrDuring1;

  /// No description provided for @instrDuring2.
  ///
  /// In en, this message translates to:
  /// **'Keep the phone, chargers and power cables away from the cables (50 Hz hum).'**
  String get instrDuring2;

  /// No description provided for @instrDuring3.
  ///
  /// In en, this message translates to:
  /// **'Wait about 10 s after pressing START, the line needs a moment to settle.'**
  String get instrDuring3;

  /// No description provided for @instrDuring4.
  ///
  /// In en, this message translates to:
  /// **'Spikes pointing DOWN usually mean RA and LA are swapped.'**
  String get instrDuring4;

  /// No description provided for @instrLengthTitle.
  ///
  /// In en, this message translates to:
  /// **'4. How long to record'**
  String get instrLengthTitle;

  /// No description provided for @instrLength1.
  ///
  /// In en, this message translates to:
  /// **'10 s: a quick look, the same length as a hospital 12-lead ECG.'**
  String get instrLength1;

  /// No description provided for @instrLength2.
  ///
  /// In en, this message translates to:
  /// **'30 s – 1 min: recommended, enough beats to see the rhythm.'**
  String get instrLength2;

  /// No description provided for @instrLength3.
  ///
  /// In en, this message translates to:
  /// **'5 min: for heart rate variability (HRV) analysis.'**
  String get instrLength3;

  /// No description provided for @instrLength4.
  ///
  /// In en, this message translates to:
  /// **'Choose the length next to the START button, the recording stops by itself.'**
  String get instrLength4;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pl':
      return AppLocalizationsPl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

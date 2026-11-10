// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get languageName => 'Polski';

  @override
  String get commonCancel => 'ANULUJ';

  @override
  String get commonShare => 'Udostępnij';

  @override
  String get commonDelete => 'Usuń';

  @override
  String get appTitle => 'EKG';

  @override
  String get homeSubtitle => 'ESP32 + ADS1194 przez Bluetooth';

  @override
  String get homeConnect => 'Połącz z urządzeniem EKG';

  @override
  String get homeRecordings => 'Nagrania';

  @override
  String get homeHowToMeasure => 'Jak wykonać pomiar';

  @override
  String get homeSettings => 'Ustawienia';

  @override
  String get homeTestSignal => 'Sygnał testowy (debug)';

  @override
  String get settingsTitle => 'Ustawienia';

  @override
  String get settingsAppearance => 'Wygląd';

  @override
  String get settingsThemeSystem => 'Systemowy';

  @override
  String get settingsLikePhone => 'Jak w telefonie';

  @override
  String get settingsThemeLight => 'Jasny';

  @override
  String get settingsThemeDark => 'Ciemny';

  @override
  String get settingsLanguage => 'Język';

  @override
  String get settingsLanguageSystem => 'Systemowy';

  @override
  String get settingsColors => 'Kolory';

  @override
  String get paletteRed => 'Czerwony';

  @override
  String get paletteBlue => 'Niebieski';

  @override
  String get paletteTeal => 'Turkusowy';

  @override
  String get paletteGreen => 'Zielony';

  @override
  String get palettePurple => 'Fioletowy';

  @override
  String get paletteOrange => 'Pomarańczowy';

  @override
  String get scannerTitle => 'Szukaj urządzeń EKG';

  @override
  String get scannerPermissionNeeded =>
      'Aplikacja potrzebuje uprawnienia Bluetooth, aby znaleźć urządzenie EKG';

  @override
  String get scannerOpenSettings => 'USTAWIENIA';

  @override
  String scannerScanFailed(String error) {
    return 'Wyszukiwanie nie powiodło się, sprawdź, czy Bluetooth jest włączony: $error';
  }

  @override
  String get scannerSearching => 'Szukam...';

  @override
  String get scannerNothingFound =>
      'Nie znaleziono urządzenia EKG.\nSprawdź, czy ESP32 jest włączone, i spróbuj ponownie.';

  @override
  String get scannerHint =>
      'Naciśnij przycisk wyszukiwania, aby znaleźć urządzenie ESP32_EKG.';

  @override
  String get scannerUnknownDevice => 'Nieznane urządzenie';

  @override
  String get scannerConnect => 'POŁĄCZ';

  @override
  String get deviceUnknown => 'Nieznane';

  @override
  String get deviceConnectionLost => 'Utracono połączenie, nagranie zapisane';

  @override
  String get deviceCouldNotConnect =>
      'Nie udało się połączyć. Czy ESP32 jest włączone i w pobliżu?';

  @override
  String get deviceServiceNotFound =>
      'Nie znaleziono usługi EKG. Czy wgrano właściwy firmware?';

  @override
  String get deviceServiceReadError =>
      'Nie udało się odczytać usługi EKG, spróbuj połączyć ponownie';

  @override
  String get deviceFileError => 'Nie udało się utworzyć pliku z danymi';

  @override
  String get deviceStartError => 'Nie udało się wysłać polecenia START';

  @override
  String get deviceIncomplete =>
      'Nagranie może być niepełne, nie udało się zapisać pliku';

  @override
  String deviceTimedFinished(String length) {
    return 'Nagranie zakończone ($length), zapisane';
  }

  @override
  String get deviceLeaveTitle => 'Zatrzymać nagrywanie?';

  @override
  String get deviceLeaveContent => 'Nagranie zostanie zatrzymane i zapisane.';

  @override
  String get deviceStopAndLeave => 'ZATRZYMAJ I WYJDŹ';

  @override
  String get deviceStateTestSignal => 'SYGNAŁ TESTOWY';

  @override
  String get deviceStateConnecting => 'ŁĄCZENIE...';

  @override
  String get deviceStateConnected => 'POŁĄCZONO';

  @override
  String get deviceStateDisconnected => 'ROZŁĄCZONO';

  @override
  String get deviceSearchingService => 'Szukam usługi EKG...';

  @override
  String get deviceLength => 'Długość:';

  @override
  String get deviceLengthManual => 'Ręcznie (do STOP)';

  @override
  String get deviceWhereElectrodes => 'Gdzie przykleić elektrody?';

  @override
  String get deviceStart => 'START';

  @override
  String get deviceStop => 'STOP';

  @override
  String deviceOfLength(String length) {
    return 'z $length';
  }

  @override
  String deviceSamples(int count) {
    return 'Próbki: $count';
  }

  @override
  String deviceLostPackets(int count) {
    return 'Zgubione pakiety: $count';
  }

  @override
  String deviceRejectedPackets(
    int count,
    int length,
    int expected,
    String mtu,
  ) {
    return 'Odrzucone pakiety: $count (długość $length zamiast $expected, MTU $mtu)';
  }

  @override
  String get deviceSavingTo => 'Zapis do:';

  @override
  String get deviceLastSaved => 'Ostatnie nagranie zapisano w:';

  @override
  String get deviceReconnect => 'POŁĄCZ PONOWNIE';

  @override
  String get recordingsUnknownDate => 'Nieznana data';

  @override
  String recordingsReadError(String error) {
    return 'Nie można odczytać nagrań:\n$error';
  }

  @override
  String get recordingsEmpty =>
      'Brak nagrań.\nRozpocznij nagrywanie na ekranie urządzenia.';

  @override
  String viewOpenError(String error) {
    return 'Nie można otworzyć nagrania:\n$error';
  }

  @override
  String get viewNoSamples => 'Nagranie nie zawiera próbek.';

  @override
  String shareSubject(String date) {
    return 'Nagranie EKG $date';
  }

  @override
  String shareError(String error) {
    return 'Nie można udostępnić: $error';
  }

  @override
  String get deleteTitle => 'Usunąć nagranie?';

  @override
  String get deleteWarning =>
      'Plik zostanie usunięty z telefonu, tego nie da się cofnąć.';

  @override
  String get deleteButton => 'USUŃ';

  @override
  String deleteError(String error) {
    return 'Nie można usunąć: $error';
  }

  @override
  String get fullscreenEnter => 'Pełny ekran';

  @override
  String get fullscreenExit => 'Zamknij pełny ekran';

  @override
  String heartRate(String value) {
    return '$value bpm';
  }

  @override
  String viewAverageBpm(String value) {
    return 'średnio $value bpm';
  }

  @override
  String chartScale(String seconds, String millivolts) {
    return '1 kratka: $seconds s × $millivolts mV';
  }

  @override
  String get instrSafetyTitle => 'Bezpieczeństwo';

  @override
  String get instrSafety1 =>
      'To projekt studencki, a nie urządzenie medyczne. Nie używaj go do diagnozy.';

  @override
  String get instrSafety2 =>
      'Zasilaj płytkę z baterii albo z laptopa pracującego na baterii, nigdy z ładowarki sieciowej, gdy elektrody są na ciele.';

  @override
  String get instrSafety3 =>
      'Przerwij pomiar, jeśli skóra pod elektrodą swędzi lub piecze.';

  @override
  String get instrElectrodesTitle => '1. Elektrody';

  @override
  String get instrElectrodesIntro =>
      'Trzy elektrody, napisy na kablu mówią, która jest która:';

  @override
  String get instrRightArm => 'Prawa ręka';

  @override
  String get instrRightArmWhere =>
      'prawy nadgarstek albo pod prawym obojczykiem';

  @override
  String get instrLeftArm => 'Lewa ręka';

  @override
  String get instrLeftArmWhere => 'lewy nadgarstek albo pod lewym obojczykiem';

  @override
  String get instrLeftLeg => 'Lewa noga';

  @override
  String get instrLeftLegWhere =>
      'lewa strona brzucha pod sercem albo lewa kostka';

  @override
  String get instrFrontView =>
      'Widok z przodu: prawa ręka osoby jest po LEWEJ stronie rysunku.';

  @override
  String get instrSkinTitle => '2. Skóra';

  @override
  String get instrSkin1 =>
      'Czysta i sucha skóra, pomaga chusteczka z alkoholem. Bez kremu i balsamu.';

  @override
  String get instrSkin2 =>
      'Świeże elektrody żelowe, stara, wyschnięta elektroda daje zaszumioną linię.';

  @override
  String get instrSkin3 =>
      'Nie na włosach, kości ani napiętym mięśniu. Dobrze dociśnij brzegi.';

  @override
  String get instrDuringTitle => '3. W trakcie pomiaru';

  @override
  String get instrDuring1 =>
      'Usiądź lub połóż się, rozluźnij się, ręce oparte. Nie mów i nie ruszaj się.';

  @override
  String get instrDuring2 =>
      'Trzymaj telefon, ładowarki i kable zasilające z dala od kabli elektrod (przydźwięk 50 Hz).';

  @override
  String get instrDuring3 =>
      'Po naciśnięciu START odczekaj ok. 10 s, linia potrzebuje chwili, żeby się ustabilizować.';

  @override
  String get instrDuring4 =>
      'Załamki skierowane w DÓŁ zwykle oznaczają zamienione RA i LA.';

  @override
  String get instrLengthTitle => '4. Jak długo nagrywać';

  @override
  String get instrLength1 =>
      '10 s: szybki podgląd, tyle samo co szpitalne 12-odprowadzeniowe EKG.';

  @override
  String get instrLength2 =>
      '30 s – 1 min: zalecane, wystarczająco dużo uderzeń, by ocenić rytm.';

  @override
  String get instrLength3 => '5 min: do analizy zmienności rytmu serca (HRV).';

  @override
  String get instrLength4 =>
      'Długość wybierz obok przycisku START, nagranie zatrzyma się samo.';
}

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
  String get commonSave => 'ZAPISZ';

  @override
  String get noteEdit => 'Notatka';

  @override
  String get noteDialogTitle => 'Notatka do nagrania';

  @override
  String get noteHint => 'np. spoczynek, po bieganiu';

  @override
  String noteSaveError(String error) {
    return 'Nie udało się zapisać notatki: $error';
  }

  @override
  String get deviceNoteLabel => 'Notatka (opcjonalnie)';

  @override
  String get deviceEvent => 'Zaznacz zdarzenie';

  @override
  String deviceEventCount(int count) {
    return 'Zaznacz zdarzenie ($count)';
  }

  @override
  String deviceEventSaved(String time) {
    return 'Zaznaczono zdarzenie: $time';
  }

  @override
  String get viewEvents => 'Zdarzenia:';

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
  String get settingsChartMatchesPalette => 'Wykres EKG w kolorach palety';

  @override
  String get settingsChartMatchesPaletteHint =>
      'Wyłączone: różowy papier (jasny) / zielony monitor (ciemny)';

  @override
  String get settingsSound => 'Dźwięk';

  @override
  String get settingsBeepOnBeat =>
      'Sygnał dźwiękowy przy każdym uderzeniu serca';

  @override
  String get settingsBeepOnBeatHint =>
      'Jak monitor w szpitalu, głośność zmieniają przyciski głośności (multimedia)';

  @override
  String get settingsAdvanced => 'Zaawansowane';

  @override
  String get settingsAdvancedFeatures => 'Funkcje zaawansowane';

  @override
  String get settingsCsvRawOnly => 'CSV tylko z surowymi wartościami';

  @override
  String get settingsCsvRawOnlyHint =>
      'Tylko numer próbki i surowa wartość z ADC, plik ok. 2 razy mniejszy. Czas = próbka / 250, mV = surowa × 0,0061. Aplikacja czyta oba rodzaje.';

  @override
  String get settingsAdvancedFeaturesHint =>
      'Szczegóły techniczne podczas pomiaru (próbki, pakiety, dBm, ścieżka pliku) i sygnał testowy bez urządzenia';

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
  String get devicePreview => 'PODGLĄD';

  @override
  String get devicePreviewStop => 'ZATRZYMAJ PODGLĄD';

  @override
  String get deviceAdsTest => 'Sygnał testowy ADS1194';

  @override
  String testSignalResult(String expected, String measured, String error) {
    return 'Oczekiwane $expected mV międzyszczytowo (prostokąt ±1 mV, ok. 1 Hz), zmierzone $measured mV ($error). Nagrane bez osoby, bez statystyk tętna.';
  }

  @override
  String get reportSignal => 'Sygnał';

  @override
  String get deviceAdsTestHint =>
      'Wewnętrzny sygnał testowy ADS1194: prostokąt ±1 mV, ok. 1 Hz, elektrody nie są mierzone. Nic nie jest zapisywane, START go nagra.';

  @override
  String get devicePreviewHint =>
      'Tylko podgląd, nic nie jest zapisywane. START nagrywa od tej chwili.';

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
  String deviceSignalStrength(int rssi, String level) {
    return 'Sygnał BLE: $rssi dBm ($level)';
  }

  @override
  String deviceSignalLevel(String level) {
    return 'Sygnał BLE: $level';
  }

  @override
  String get deviceSomeDataLost =>
      'Część danych nie dotarła, przybliż telefon do urządzenia';

  @override
  String get deviceRecordingSaved =>
      'Nagranie zapisane, znajdziesz je na liście nagrań';

  @override
  String get signalStrong => 'silny';

  @override
  String get signalFair => 'średni';

  @override
  String get signalWeak => 'słaby – przysuń telefon bliżej';

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
  String get statsTitle => 'Statystyki nagrania';

  @override
  String get reportButton => 'Raport PDF';

  @override
  String get reportTitle => 'Raport EKG';

  @override
  String get reportStart => 'Początek';

  @override
  String get reportLength => 'Długość';

  @override
  String get reportDevice => 'Urządzenie';

  @override
  String get reportNote => 'Notatka';

  @override
  String reportEkg(int speed, int gain) {
    return 'EKG ($speed mm/s, $gain mm/mV, filtr 0,5–40 Hz)';
  }

  @override
  String reportStripsRange(String from, String to, int skipped) {
    return '$from – $to nagrania, pierwsze $skipped s pominięte (sygnał ustala się po START).';
  }

  @override
  String get reportEventStrips => 'Zaznaczone zdarzenia';

  @override
  String get reportArtifactStrips => 'Zakłócenia wykryte przez aplikację';

  @override
  String reportArtifactStrip(String label, String from, String to) {
    return 'Zakłócenie w $label ($from – $to)';
  }

  @override
  String get viewArtifacts => 'Zakłócenia:';

  @override
  String reportEventStrip(String time, String from, String to) {
    return 'Zdarzenie w $time ($from – $to)';
  }

  @override
  String get reportDisclaimer =>
      'Wykonano w projekcie studenckim, to nie jest wyrób medyczny – nie służy do diagnozy.';

  @override
  String reportError(String error) {
    return 'Nie udało się utworzyć raportu: $error';
  }

  @override
  String get statsNotEnoughBeats => 'Za mało uderzeń serca do statystyk.';

  @override
  String get statsMin => 'Min.';

  @override
  String get statsAverage => 'Średnio';

  @override
  String get statsMax => 'Maks.';

  @override
  String statsBeats(int beats, int excluded) {
    return 'Uderzenia: $beats, pominięte odstępy: $excluded (zgubione uderzenia, artefakty)';
  }

  @override
  String get statsTachogram => 'Odstępy RR w czasie (tachogram)';

  @override
  String get statsHrvHint =>
      'HRV (SDNN, RMSSD) jest wiarygodne tylko dla spokojnego nagrania trwającego co najmniej 1 minutę, bez ruchu.';

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
  String get qualityChecking => 'Sprawdzam sygnał…';

  @override
  String get qualityGood => 'Dobry sygnał';

  @override
  String get qualityNoisy =>
      'Zaszumiony sygnał – siedź spokojnie, rozluźnij mięśnie, dociśnij elektrody';

  @override
  String get qualityNoBeats =>
      'Brak wyraźnych uderzeń serca – sprawdź elektrody';

  @override
  String get qualityFlat => 'Brak sygnału – odpięta elektroda lub kabel?';

  @override
  String get qualityElectrodeOff =>
      'Sygnał poza zakresem – elektroda odpięta lub luźna';

  @override
  String viewAverageBpm(String value) {
    return 'średnio $value bpm';
  }

  @override
  String get chartZoomAuto => 'Auto';

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
      'Trzy elektrody, kolory takie jak na kablu z zestawu:';

  @override
  String get instrCableRightArm => 'zielony przewód, napis R';

  @override
  String get instrCableLeftArm => 'czerwony przewód, bez napisu';

  @override
  String get instrCableLeftLeg => 'żółty przewód, napis L';

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
      'Najpierw włącz PODGLĄD i poczekaj, aż linia się uspokoi (ok. 10 s), dopiero potem naciśnij START.';

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

  @override
  String get rhythmTitle => 'Rytm';

  @override
  String get rhythmNormal => 'Tętno w normie (60–100 bpm)';

  @override
  String get rhythmSlow => 'Wolne tętno (poniżej 60 bpm, bradykardia)';

  @override
  String get rhythmFast => 'Szybkie tętno (powyżej 100 bpm, tachykardia)';

  @override
  String rhythmPremature(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count pobudzeń przedwczesnych (dodatkowych uderzeń, które przyszły za wcześnie)',
      few:
          '$count pobudzenia przedwczesne (dodatkowe uderzenia, które przyszły za wcześnie)',
      one:
          '1 pobudzenie przedwczesne (dodatkowe uderzenie, które przyszło za wcześnie)',
      zero: 'Nie znaleziono pobudzeń przedwczesnych',
    );
    return '$_temp0';
  }

  @override
  String get rhythmHint =>
      'Automatyczna ocena z jednego odprowadzenia: wykrywa ok. 2 z 3 pobudzeń przedwczesnych, szerokość QRS i QT mogą się różnić od szpitalnego EKG 12-odprowadzeniowego, a wolne tętno w spoczynku bywa normalne u osób wytrenowanych. Nietypowy wynik skonsultuj z lekarzem.';

  @override
  String get viewPremature => 'Pobudzenia przedwczesne:';

  @override
  String viewMoreChips(int count) {
    return '+$count więcej';
  }

  @override
  String qrsTypical(int ms) {
    return 'Typowa szerokość QRS: $ms ms (szeroki od 120 ms)';
  }

  @override
  String qrsTypicalWide(int ms) {
    return 'Typowa szerokość QRS: $ms ms, poszerzony QRS (120 ms lub więcej)';
  }

  @override
  String get qrsNotMeasured =>
      'Szerokość QRS: nie zmierzono (za mało regularnych uderzeń albo za dużo zakłóceń)';

  @override
  String rhythmPrematureWide(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'w tym $count o innym kształcie lub szerokim QRS (prawdopodobnie komorowe)',
      few:
          'w tym $count o innym kształcie lub szerokim QRS (prawdopodobnie komorowe)',
      one:
          'w tym 1 o innym kształcie lub szerokim QRS (prawdopodobnie komorowe)',
      zero:
          'żadne o innym kształcie lub szerokim QRS (prawdopodobnie nadkomorowe)',
    );
    return '$_temp0';
  }

  @override
  String qrsMedianBeat(int count) {
    return 'Uśrednione uderzenie (mediana $count regularnych uderzeń), zaznaczony QRS';
  }

  @override
  String viewPrematureWide(String time) {
    return '$time komorowe';
  }

  @override
  String afSuspected(int seconds) {
    return 'Nieregularny rytm przez $seconds s: możliwe migotanie przedsionków lub bardzo częste pobudzenia dodatkowe';
  }

  @override
  String get afNone =>
      'Brak nieregularnego rytmu typowego dla migotania przedsionków (30 s lub dłużej)';

  @override
  String get viewIrregular => 'Nieregularny rytm:';

  @override
  String rhythmRuns(int pairs, int runs) {
    return 'Pobudzenia komorowe jedno po drugim: par $pairs, salw (3 lub więcej) $runs';
  }

  @override
  String get rhythmNoPauses => 'Brak pauz 2 s lub dłuższych';

  @override
  String rhythmPauses(int count, double seconds) {
    final intl.NumberFormat secondsNumberFormat =
        intl.NumberFormat.decimalPatternDigits(
          locale: localeName,
          decimalDigits: 1,
        );
    final String secondsString = secondsNumberFormat.format(seconds);

    return 'Pauzy 2 s lub dłuższe: $count, najdłuższa $secondsString s';
  }

  @override
  String get viewPauses => 'Pauzy:';

  @override
  String viewRun(String time, int count) {
    return '$time $count z rzędu';
  }

  @override
  String get viewRuns => 'Komorowe z rzędu:';

  @override
  String qtValues(int qt, int bazett, int fridericia) {
    return 'QT $qt ms, QTc $bazett ms (Bazett) / $fridericia ms (Fridericia)';
  }

  @override
  String get qtNormal => 'QTc w normie (350–460 ms)';

  @override
  String get qtLong => 'Wydłużony QTc (powyżej 460 ms)';

  @override
  String get qtShort => 'Skrócony QTc (poniżej 350 ms)';

  @override
  String get qtNotMeasured =>
      'QT: nie zmierzono, załamek T jest zbyt płaski w tym odprowadzeniu (może pomóc inne ułożenie elektrod)';

  @override
  String get rhythmWarning => 'To nie jest diagnoza medyczna.';
}

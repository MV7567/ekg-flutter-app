import 'dart:async';                                        // timer, stream subscription
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';  // UUID, packetLenght, sampleRateHz
import '../ekg_config.dart';                                // bytes -> samples
import '../ekg_buffer.dart';                                // saving to CSV
import '../ekg_packet_decoder.dart';                        // chart filters
import '../l10n/app_localizations.dart';                   // translations
import '../heart_rate_detector.dart';                       // bpm
import '../ekg_test_signal.dart';                           // fake ESP32 (debug)
import '../recording/csv_recorder.dart';                    // drawing the chart
import '../filters/biquad_filter.dart';                     
import '../widgets/ekg_chart.dart';
import '../widgets/fullscreen_chart.dart';
import '../widgets/heart_rate_text.dart';
import '../settings/app_settings.dart';                     // recording length
import 'instructions_screen.dart';                          // how to measure

// device screen, stateful widget, because we need to update the UI when connecting and recording
class DeviceScreen extends StatefulWidget {
  final BluetoothDevice? device;   // null = test signal instead of the ESP32
  // in BLE functions (connect, discoverServices...) there is widget.device! because in test mode the functions are never called 
  // where the device cant be, there is ?.: mtuNow and disconnect() in dispose

  const DeviceScreen({super.key, required BluetoothDevice this.device});

  // debug only: the app makes the signal itself (EkgTestSignal), no BLE, no board needed
  const DeviceScreen.testSignal({super.key}) : device = null;

  // text for the recording length: 0 -> "Manual", 30 -> "30 s", 120 -> "2 min", 90 -> "1:30"
  // static so it can be tested
  static String durationLabel(int seconds) {
    if (seconds <= 0) return 'Manual';
    if (seconds < 60) return '$seconds s';
    if (seconds % 60 == 0) return '${seconds ~/ 60} min';
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  } // a regulat constructor requires a real device so during connect you cant accidentaly get null
  // the same scheme as the scanner, the main difference: widget gets the parameter device, meaning the device clicked in the scanner  (DeviceScreen(device: result.device)).
  // - required means, without this parameter the code wont compile
  // this.device assigns the parameter to the field immediately
  // the field is final because the widget is unchangeable

  // State class reads the field through widget.device. widget is a built-in field of State class 

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  // actual connection state, displayed with big letters. Enum type, meaning a closed list of possbile values (connected, disconnected...). Starting state is disconnected

  // control characteristic for start/stop, null until the services are discovered
  BluetoothCharacteristic? _controlCharacteristic;
  // ? means the variable can be null (doesnt exist yet). Before using this it has to be checked if its null or use ? or !. 
  // the value is null until we find the characteristic in ESP32 services and returns to null after disconnecting, because the old object is then useless

  // recording state
  bool _isConnecting = false; // true while connect() is running (the plugin has no "connecting" state on Android)
  bool _isRecording = false;
  bool _isBusy = false;       // true while a start/stop command is being sent
  // _isRecording says whether there is a recording in progress, whether the packets end up in the file and which label is on the button depend on this
  // _isBusy is set during sending the start/stop command, the button is turned off then

  final CsvRecorder _recorder = CsvRecorder();   // writes the samples to the CSV file
  final EkgPacketDecoder _decoder = EkgPacketDecoder();   // bytes -> samples, counts lost packets
  // Modules form steps a and b. final means the object is always the same, even if its interior changes (opens files, counts packets)

  Timer? _uiTimer;            // refreshes the recording info on the screen
  // timer that every 500 ms refreshes the screen, recording time and counters. It's null if it's not recording

  // objects to control the data streams, both have to be cancelled in dispose
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;
  StreamSubscription<List<int>>? _bleSubscription;
  // 2 subscriptions like in the scanner:
  // - connection state: works for the entire time the screen lives
  // - EKG data: created with every connection. List<int> type says that every event is a byte list, meaning one packet
  // they are with ? and not late final, because _bleSubscription changes with every next connection

  // last 5 seconds of the signal for the chart (5 s x 250 Hz = 1250 samples)
  final EkgBuffer _chartBuffer = EkgBuffer(sampleRateHz * 5);

  // filters for the chart only (0.5 Hz high-pass, 50 Hz + 100 Hz notch, 40 Hz low-pass),
  // the CSV file keeps the raw values, so they can be filtered differently later
  final EkgDisplayFilter _displayFilter = EkgDisplayFilter(sampleRateHz.toDouble());

  // heart rate from the R waves of the filtered signal (see HeartRateDetector)
  // ValueNotifier: the bpm text redraws by itself when the value changes, without setState
  final HeartRateDetector _heartRate = HeartRateDetector(sampleRateHz);
  final ValueNotifier<int?> _bpm = ValueNotifier(null);   // null = not known yet
  // chart filters: .toDouble() is needed because sampleRateHz is int, and the filters works on decimal vals

  // chart amplitude scale: how many mV one big square means
  // 0.5 = standard EKG paper (10 mm/mV), smaller value = bigger line
  double _mvPerBigSquare = 0.25;
  // scale form the switch x1/x2/x4

  // timed recording: number of samples after which the recording stops, null = manual (until STOP)
  int? _sampleLimit;

  // test signal mode: the generator calls _processEkgData like the BLE notifications do
  bool get _isTestSignal => widget.device == null;
  late final EkgTestSignal? _testSignal = _isTestSignal ? EkgTestSignal(_processEkgData) : null;
  // late is needed because the initializator uses widget and _processEkgData and those are avaible after creating State object

  @override
  void initState() {
    super.initState();
    if (_isTestSignal) {
      // nothing to connect to, the screen is ready at once
      _connectionState = BluetoothConnectionState.connected;
    } else {
      _connectToDevice();
    }
  }
  // the screen begins to connect immediately after opening. Like in the scanner, without await, because initState cant be async

  // ---------------- BLE connection ----------------

  Future<void> _connectToDevice() async {
    // a second connect() while the first one is still running would only cause errors
    if (_isConnecting) return;

    // listen to the connection state (on Android only connected / disconnected)
    // the stream does NOT wait for this async function: if two states come quickly one after another,
    // the second one can start before the first one finished its await.
    // it is safe here, because _discoverAndSubscribe cancels the old subscription first
    // and _finishRecording can be called twice
    _connectionSubscription ??= widget.device!.connectionState.listen((state) async {
      // ??== means write only when the variable is null. the function is called also from the RECONNECT button, and thanks to ??== a subscription i created only the first time
      // Without it every next connection would add another listener and the "connection lost" would appear 2, 3, 4 etc times
      // connectionState is this devices change state stream
      // (state) async {...}: the listening function is async, because it has await inside to discover services 
      if (mounted) {
        setState(() {
          _connectionState = state;
        });
      }
      // Updating state. mounted is checked for the same reason as in the scanner 

      if (state == BluetoothConnectionState.connected) {
        // when connected, discover services
        await _discoverAndSubscribe();
        // After connecting we also have to discover services. Just the connection doesn't say what characteristics the device has, it has to be asked
      } else if (state == BluetoothConnectionState.disconnected) {
        // the ESP32 stops measuring by itself when the phone disconnects,
        // so the file is closed here to keep the data recorded so far
        _controlCharacteristic = null;
        if (_isRecording) {
          // if saving failed, _finishRecording already showed a warning
          if (await _finishRecording()) _showMessage((t) => t.deviceConnectionLost);
        }
      }
      // breaking the connection, 
      // - we forget the steering characteristic, so the start button disappears
      // - if there was a recording in progress, close the file, the data is safe
      // ESP32 interrupts the measurement in the case of disconnecting, so both sides end a the same moment
    });

    // attempt to connect to the esp32 (on Android this also requests a bigger MTU,
    // needed because one packet is 21 bytes and the default MTU only allows 20)
    setState(() => _isConnecting = true);
    try {
      await widget.device!.connect();
    } catch (e) {
      // e.g. the ESP32 is off or too far away, connect() gives up after 35 s
      debugPrint("Connection error: $e");
      _showMessage((t) => t.deviceCouldNotConnect);
    } finally {
      // finally runs always: after success and after an error
      if (mounted) setState(() => _isConnecting = false);
    }
  }
  // correct connection. on android connect() immediately asks for MTU 512 too, aka larger packets.
  // its needed because the packet has 21 bytes, while default MTU (23) fits only 20 bytes. The result of the connection comes through the stream connectionState, 
  // not from this function. Its the same as the scanning: the function only activates the action but the results come through the stream

  // discover services and subscribe to the target characteristic
  Future<void> _discoverAndSubscribe() async {
    try {
      // cancel a subscription left over from a previous connection, so data is never written twice
      await _bleSubscription?.cancel();
      _bleSubscription = null;
      // ?. means cal if not null. if there is a remaining subscription from a previous connection, we turn it off.
      // otherwise after RECONNECT every packet would be saved twice

      List<BluetoothService> services = await widget.device!.discoverServices();
      bool foundDataCharacteristic = false;
      // we aks the esp32 for a list of every service and characteristic, exchanging a couple messages lasts a split second

      for (BluetoothService service in services) {
        // searching for the target service and characteristics
        if (service.uuid != ekgServiceUuid) continue;
        // scans every element of the list, continue means take the next element and skip the rest. 
        // esp32 also has other standard system services that we dont need

        for (BluetoothCharacteristic characteristic in service.characteristics) { 
          if (characteristic.uuid == ekgCharacteristicUuid) {
            debugPrint("Found data characteristic, subscribing...");
            foundDataCharacteristic = true;
            // Inside our service we are looking for 2 characteristics by the UUID

            // onValueReceived only gives new notifications
            // (lastValueStream would also repeat the last cached value right away)
            _bleSubscription = characteristic.onValueReceived.listen(_processEkgData);
            // every packet from the esp32 calls _processEkgData(bajty). Like in the scanner button we pass just the function, without the paranthesis.
            // onValueReceived only gives new notifications. lastValueStream would immediately would repeat the last remembered value, which would double the first packet

            // the plugin cancels the subscription by itself when the device disconnects
            widget.device!.cancelWhenDisconnected(_bleSubscription!);
            // The plugin will turn off the subscription on its own when disconnected. ! means we know its not null. we're sure because it was assigned in the prievious line 
            // but if it actually was null it would throw an error so only use ! when sure the value exists

            // enable notifications for the characteristic (after listening, so no packet is missed)
            await characteristic.setNotifyValue(true);
            // turns on the notifications, ie requests the esp32 to notify about this characteristics change, do this after listen, not to lose the first packet, 
            // the other way around could cause the first packet to arrive before anyone is listening
          } else if (characteristic.uuid == ekgControlCharacteristicUuid) {
            debugPrint("Found control characteristic");
            _controlCharacteristic = characteristic;
          }
          // we remember the control characteristic, from this moment ready is true and the START button appears
        }
      }

      // without both characteristics the device is useless -> disconnect, so RECONNECT appears
      // instead of the "Searching for the EKG service..." spinner forever
      if (!foundDataCharacteristic || _controlCharacteristic == null) {
        await _disconnectWithMessage((t) => t.deviceServiceNotFound);
        return;
      }
      if (mounted) setState(() {});
      // warning for the old firmaware without start/stop. setState(() {}) with the empty funcion means nothing changes in this function but redraw the screen. 
      // because _controlCharacteristic changed outside of setState.
    } catch (e) {
      debugPrint("Service discovery error: $e");
      // the same as above: no spinner forever, the user can try again
      if (widget.device!.isConnected) {
        await _disconnectWithMessage((t) => t.deviceServiceReadError);
      }
    }
    // eg. disconnecting during discovering services
  }

  // shows why, then disconnects -> the state becomes disconnected and RECONNECT appears
  Future<void> _disconnectWithMessage(String Function(AppLocalizations t) message) async {
    _showMessage(message);
    try {
      await widget.device!.disconnect();
    } catch (e) {
      debugPrint("Disconnect error: $e");
    }
  }

  // ---------------- start / stop ----------------

  Future<void> _startRecording() async {
    if (_controlCharacteristic == null && !_isTestSignal) return;
    setState(() => _isBusy = true);
    // without the control characteristic there is no way to send START, so the function finishes immediately. 
    // in practise the button is hidden anyway in that moment, its just a safety thing. Later _isBusy = true turns off the button for the start time

    // setState(() => _isBusy = true) is short for setState(() { _isBusy = true; })

    // a new file for every measurement
    // "TEST_SIGNAL" in the CSV header, so test files are easy to tell apart in Recordings
    bool fileReady = await _recorder.open(deviceName: widget.device?.platformName ?? 'TEST_SIGNAL');
    if (!fileReady) {
      _showMessage((t) => t.deviceFileError);
      if (mounted) setState(() => _isBusy = false);   // the user could have left the screen during await
      return;
    }
    // First the file and then the ESP32 command. If the file can't be created there is no point to start the measurement. 
    // ! before a bool type means not. Unlike ! w _bleSubscription which means not null

    // timed recording: the length is fixed now, changing the choice later does not change this recording
    int seconds = AppSettings.instance.recordingSeconds;
    _sampleLimit = seconds > 0 ? seconds * sampleRateHz : null;

    _decoder.reset();
    _chartBuffer.clear();   // the chart starts empty for every recording
    _displayFilter.reset(); // and the filters forget the previous recording
    _heartRate.reset();     // and the beat detector too
    _bpm.value = null;
    _isRecording = true;   // set before the command, so the first packet is not ignored
    // readying new recording:
    // - packet counters
    // - empty chart
    // - filters without memory

    try {
      // tell the ESP32 to start the ADC and send data
      if (_testSignal != null) {
        _testSignal.start();   // test mode: the generator sends the packets instead
      } else {
        await _controlCharacteristic!.write([controlStart]);
      }
      // saving one byte 0x01 to the control characteristic.
      // [controlStart] is a list with one element, because write always accepts a byte list. 
      // on the esp32 ControlCallbacks::onWrite is called, which sets startRequested = true
    } catch (e) {
      debugPrint("Start command error: $e");
      _showMessage((t) => t.deviceStartError);
      await _finishRecording();
      if (mounted) setState(() => _isBusy = false);
      return;
    }
    // if START doesn't work, we close the open file, otherwise there would be an empty file with just a header and open "handle"

    // the screen was closed during await -> dispose already ran, a timer started now would never be cancelled
    if (!mounted) return;

    // refresh the time / sample counters twice per second
    _uiTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
    // Timer.periodic calls the fnction every 500 ms, until cancel().
    // (_): the function gets a parameter (just the timer), which we're not using, and _ is the convention (we dont care about this parameter)

    // why timer and not setState with every packet? There's 25 packets per second, and redrawing the whole screen 25 times per second only to change the counter is wastefull
    // 2 times per second is enough, the chart refreshes separately through repaint: buffer

    if (mounted) setState(() => _isBusy = false);
  }

  Future<void> _stopRecording() async {
    setState(() => _isBusy = true);
    _testSignal?.stop();   // test mode, null with the ESP32
    try {
      // tell the ESP32 to stop the ADC
      await _controlCharacteristic?.write([controlStop]);
    } catch (e) {
      debugPrint("Stop command error: $e");
    }
    await _finishRecording();
    // sends byte 0x00. This time there is ?. instead of !: if the characteristic disappears (disconnecting), the save is just skipped
    // STOP error doesnt interrupt the file closing, _finishRecording will happen always because the data is more important than getting the confirm from the esp32
    if (mounted) setState(() => _isBusy = false);
  }
  

  // stops writing and closes the file, packets arriving after this are ignored
  // returns false if the file could not be written completely
  Future<bool> _finishRecording() async {
    _isRecording = false;
    _uiTimer?.cancel();
    _uiTimer = null;

    // writes the rest, closes the file and registers it in the file manager
    bool saved = await _recorder.close();
    if (!saved) _showMessage((t) => t.deviceIncomplete);

    if (mounted) setState(() {});
    return saved;
  }
  // the order matters:
  // 1. _isRecording = false is first, from this moment _processEkgData turns away packets, even if the esp32 has enough time to sent one more
  // 2. stops the refreshing clock
  // 3. closes the file
  // 4. redrawing: the start button returns, and "last recording saved in..." appears

  // ---------------- incoming data ----------------

  // function to process the EKG data received from the characteristic, called 25 times per second, once for every packet
  void _processEkgData(List<int> data) {
    // ignore data when not recording (e.g. a last packet arriving right after stop)
    // checking isOpen is the second safety measure in case the file closes for a different place.
    if (!_isRecording || !_recorder.isOpen) return;

    EkgPacket? packet = _decoder.decode(data);
    if (packet == null) {
      // wrong length (usually MTU) or a duplicate, the decoder counts both
      debugPrint("Packet skipped: length ${data.length}, MTU ${widget.device?.mtuNow}, "
          "duplicates ${_decoder.duplicatePackets}");
      return;
    }
    // decoder from the previous step, null means a wrong packet. the decoder has already counted it, we only write the MTU to the terminal because its the most common reason

    // the 10 values of this packet in mV, for the chart
    List<double> packetMillivolts = [];

    for (int i = 0; i < packet.rawValues.length; i++) {
      // timed recording: samples after the chosen length are not saved, the file is exactly 30 s etc.
      if (_sampleLimit != null && packet.firstSampleIndex + i >= _sampleLimit!) break;
      int rawValue = packet.rawValues[i];
      _recorder.writeSample(packet.firstSampleIndex + i, rawValue);   // raw value to the file
      double millivolts = rawValue * millivoltsPerLsb;
      double filtered = _displayFilter.process(millivolts);
      packetMillivolts.add(filtered);   // filtered value for the chart
      _heartRate.addSample(packet.firstSampleIndex + i, filtered);   // and for the beat detector
    }
    // It's a classic for loop: start from i=0, condition i<10, and i++.
    // for every one of the 10 samples:
    // - the file receives the raw value, the number of the sample is the number of the first in the packet plus the the position in the packet
    // - the chart gets the filtered and converted value, the samples have to go to the filter in order because it remembers the previous ones

    // one call per packet -> the chart repaints 25 times per second
    _chartBuffer.addAll(packetMillivolts);
    // the full 10 samples goes to the buffer at once, (one call of notifyListeners()) and one redrawing the screen per packet.
    // With add for every sample with notification it would be 250 refreshes per sec and the phone screen shows 60 or 120 frames anyway

    // ValueNotifier tells its listeners only when the number really changes
    _bpm.value = _heartRate.bpm;

    // the chosen length is reached -> stop like the STOP button,
    // !_isBusy: the next packets arrive while stopping, stop only once
    if (_sampleLimit != null && _decoder.sampleCount >= _sampleLimit! && !_isBusy) {
      _finishTimedRecording();
    }
  }

  Future<void> _finishTimedRecording() async {
    await _stopRecording();
    _showMessage((t) => t.deviceTimedFinished(DeviceScreen.durationLabel(_sampleLimit! ~/ sampleRateHz)));
  }

  // ---------------- leaving the screen ----------------

  // called by PopScope when the user goes back (gesture, button or the arrow in the top bar)
  // didPop = true -> the screen is already closing (not recording, nothing to ask)
  Future<void> _confirmLeave(bool didPop) async {
    if (didPop) return;

    // showDialog waits until the dialog is closed and returns the value given to pop()
    AppLocalizations t = AppLocalizations.of(context);
    bool? leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.deviceLeaveTitle),
        content: Text(t.deviceLeaveContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.deviceStopAndLeave),
          ),
        ],
      ),
    );
    // null = closed by tapping outside the dialog, the same as CANCEL
    if (leave != true) return;

    // stop properly (STOP command + closing the file), then close the screen
    await _stopRecording();
    if (mounted) Navigator.of(context).pop();
  }

  // ---------------- helpers ----------------

  // gets a function that picks the text, e.g. (t) => t.deviceFileError:
  // the text is chosen only after the mounted check, because AppLocalizations.of(context)
  // can't be used any more when the screen is gone (messages often come after an await)
  void _showMessage(String Function(AppLocalizations t) text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text(AppLocalizations.of(context)))),
    );
  }
  // one space for snackbar, checks mounted, dont have to remeber about it with every 

  // recording time as mm:ss, counted from the samples (250 samples = 1 second)
  String get _recordingTime {
    int seconds = _decoder.sampleCount ~/ sampleRateHz;
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
  // get -> getter, no (), value is calced with every read
  // ~/ integer division
  // % the rest
  // padLeft(2, '0'), fills with zeros to the left to to 2 chars
  // ${...} interpolation of an expresion (just for a variable its $e)

  // the time is calced from the samples no the phones clock, it shows how much of the signal was lost and the holes from lost packets

  @override
  void dispose() {
    // closing order
    // 1. Cancel the BLE subscriptions and the UI timer
    _uiTimer?.cancel();
    _testSignal?.stop();
    _bleSubscription?.cancel();
    _connectionSubscription?.cancel();
    // 2. Close the file (leaving the screen during a recording), not awaited, dispose can't wait
    _isRecording = false;
    _recorder.close();
    // 3. Disconnect the device (the ESP32 stops the measurement when the phone disconnects)
    // catchError: an error here (e.g. already disconnected) is only printed, not "Unhandled exception"
    widget.device?.disconnect().catchError((e) => debugPrint("Disconnect error: $e"));
    // 4. Free the chart buffer (it is a ChangeNotifier, the chart stops listening to it)
    _chartBuffer.dispose();
    _bpm.dispose();
    super.dispose();
  }

  // ---------------- UI ----------------

  String get _deviceTitle {
    BluetoothDevice? device = widget.device;
    if (device == null) return AppLocalizations.of(context).homeTestSignal;
    return device.platformName.isEmpty ? AppLocalizations.of(context).deviceUnknown : device.platformName;
  }

  @override
  Widget build(BuildContext context) {
    bool connected = _connectionState == BluetoothConnectionState.connected;
    bool ready = connected && (_controlCharacteristic != null || _isTestSignal);
    bool connecting = _isConnecting && !connected;
    // additional variables to make condition statements more readable
    AppLocalizations t = AppLocalizations.of(context);   // texts in the chosen language

    return Scaffold(
      appBar: AppBar(
        title: Text(_deviceTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: t.homeHowToMeasure,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const InstructionsScreen()),
            ),
          ),
        ],
      ),
      // the name of the device in the bar
      // PopScope: during a recording going back first asks (see _confirmLeave)
      // SafeArea: not under the navigation bar (on the side in landscape)
      body: SafeArea(
        child: PopScope(
        canPop: !_isRecording,
        onPopInvokedWithResult: (didPop, result) => _confirmLeave(didPop),
        // LayoutBuilder gives the size of the free space (constraints), needed below
        child: LayoutBuilder(
          // the content can be scrolled if it doesn't fit (landscape, small screen, big font)
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),  // adds 16 pixels on every side
            // at least as high as the screen, so the Column can still center its content
            // (32 = padding top + bottom)
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
              child: Column(  // arranges the kids vertically
                mainAxisAlignment: MainAxisAlignment.center,  // centers the vertical list
                children: [
                  // live EKG chart
                  SizedBox( // the size and shape of the chart
                    height: 200,
                    width: double.infinity, // means as far as itll go
                    // Stack: the full screen button lies on top of the chart, top right corner
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: EkgChart(
                            buffer: _chartBuffer,
                            sampleRateHz: sampleRateHz,
                            mvPerBigSquare: _mvPerBigSquare,
                          ),
                        ),
                        Positioned(top: 0, right: 0, child: FullscreenButton(onPressed: _openFullscreen)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),  // empty sized box as an element separator 

                  // amplitude zoom, like the 5/10/20 mm/mV switch on EKG machines
                  SegmentedButton<double>(
                    segments: const [
                      ButtonSegment(value: 0.5, label: Text('×1')),
                      ButtonSegment(value: 0.25, label: Text('×2')),
                      ButtonSegment(value: 0.125, label: Text('×4')),
                    ],
                    selected: {_mvPerBigSquare},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        setState(() => _mvPerBigSquare = selection.first),
                  ),
                  // Scale switch:
                  // every segment is a double
                  // selected gets a Set{}, because segmentation button can allow choosing multiple segments at once (here we have one)
                  const SizedBox(height: 20),

                  // connection state
                  Text(
                    _isTestSignal ? t.deviceStateTestSignal : (connecting ? t.deviceStateConnecting : (connected ? t.deviceStateConnected : t.deviceStateDisconnected)),   // .name changes the enum value to text, and makes it uppercase
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: connected ? Colors.green : (connecting ? Colors.orange : Colors.red),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // connect() is running
                  if (connecting) const CircularProgressIndicator(),

                  // connected, but the services are not discovered yet
                  if (connected && !ready) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 10),
                    Text(t.deviceSearchingService),
                  ],

                  // recording length, only before START (a running recording keeps its length)
                  if (ready && !_isRecording) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('${t.deviceLength} '),
                        DropdownButton<int>(
                          value: AppSettings.instance.recordingSeconds,
                          items: [
                            for (int s in AppSettings.recordingSecondsOptions)
                              DropdownMenuItem(
                                value: s,
                                child: Text(s == 0 ? t.deviceLengthManual : DeviceScreen.durationLabel(s)),
                              ),
                          ],
                          // saved, so the next recording (also after a restart) has the same length
                          onChanged: (s) {
                            if (s == null) return;
                            AppSettings.instance.setRecordingSeconds(s);   // changes the value at once, saves in the background
                            setState(() {});   // redraw the dropdown with the new value
                          },
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const InstructionsScreen()),
                      ),
                      child: Text(t.deviceWhereElectrodes),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // start / stop button
                  if (ready)
                    SizedBox(
                      width: 200,
                      height: 60,
                      child: FilledButton.icon(   // button with an icon and text
                        style: FilledButton.styleFrom(  // changes the background colors
                          backgroundColor: _isRecording ? Colors.red : Colors.green,
                        ),
                        onPressed: _isBusy ? null : (_isRecording ? _stopRecording : _startRecording),  // null, stop or start
                        icon: Icon(_isRecording ? Icons.stop : Icons.play_arrow),
                        label: Text(_isRecording ? t.deviceStop : t.deviceStart, style: const TextStyle(fontSize: 20)),
                      ),
                    ),
                    // all the properties depend on _isRecording so the button always matches the state

                  // recording info, only visible during the recording, 
                  if (_isRecording) ...[
                    const SizedBox(height: 30),
                    Text(_recordingTime, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                    HeartRateText(bpm: _bpm, fontSize: 28),
                    // timed recording: how much of the chosen length is done
                    if (_sampleLimit != null) ...[
                      Text(t.deviceOfLength(DeviceScreen.durationLabel(_sampleLimit! ~/ sampleRateHz))),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 200,
                        child: LinearProgressIndicator(
                          value: (_decoder.sampleCount / _sampleLimit!).clamp(0.0, 1.0),   // 0..1
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(t.deviceSamples(_decoder.sampleCount)),
                    Text(t.deviceLostPackets(_decoder.lostPackets),
                      style: TextStyle(color: _decoder.lostPackets > 0 ? Colors.orange : null)), // null colors means the default, 
                      // the lost packet list becomes orange when the number is bigger than zero
                    // packets of the wrong size are not saved, usually the MTU is too small
                    if (_decoder.badPackets > 0)
                      Text(t.deviceRejectedPackets(_decoder.badPackets, _decoder.lastBadLength, packetLength, '${widget.device?.mtuNow}'),
                        style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                  ],

                  // last saved file
                  if (_recorder.filePath.isNotEmpty) ...[
                    const SizedBox(height: 30),
                    Text(_isRecording ? t.deviceSavingTo : t.deviceLastSaved,
                      style: const TextStyle(fontSize: 14)),
                    Text(_recorder.filePath,
                      style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
                  ],
                  // the file path appears from the first recording, during "Saving to:", after "Last recording saved in:"

                  // reconnect after the connection was lost
                  if (_connectionState == BluetoothConnectionState.disconnected && !connecting) ...[
                    const SizedBox(height: 30),
                    OutlinedButton.icon(
                      onPressed: _connectToDevice,
                      icon: const Icon(Icons.refresh),
                      label: Text(t.deviceReconnect),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  // the same chart buffer, so the live signal keeps drawing in full screen
  Future<void> _openFullscreen() async {
    double? mv = await FullscreenChartScreen.open(
      context,
      buffer: _chartBuffer,
      sampleRateHz: sampleRateHz,
      mvPerBigSquare: _mvPerBigSquare,
      bpm: _bpm,   // the heart rate is shown there too
    );
    if (mv != null && mounted) setState(() => _mvPerBigSquare = mv);   // zoom chosen in full screen
  }
}

import 'dart:async';
import 'dart:io';                                             // Platform.isAndroid
import 'package:device_info_plus/device_info_plus.dart';      // Android version
import 'package:flutter/foundation.dart';                     // kDebugMode
import 'package:flutter/material.dart';                       // import ui stuff
import 'package:flutter_blue_plus/flutter_blue_plus.dart';    // import bluetooth stuff
import 'package:permission_handler/permission_handler.dart';  // import permission stuff
import '../ekg_config.dart';  //higher up folder
import 'device_screen.dart';
import 'recordings_screen.dart';
import 'settings_screen.dart';

// scanner, stateful widget, because we need to update the UI when scanning
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}
// StatefulWidget always has 2 classes, 
// ScannerScreen is the widget class, lightweight, holds the configuration,
// _ScannerScreenState is the state class, created once and exists as long as the screen is visible, there's changing data
// createState connects these 2 classes, => means return the result of the expression after it, same as { return _ScannerScreenState(); }
// _ means the class is private for this file 

// state class for the scanner screen
class _ScannerScreenState extends State<ScannerScreen> {
  bool _isScanning = false;             // flag to indicate if scanning is in progress
  bool _hasScanned = false;             // true after the first scan, for the "nothing found" text
  List<ScanResult> _scanResults = [];   // list to hold scan results

  // subscriptions are created once and cancelled in dispose,
  // so every scan doesn't add another listener
  late final StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late final StreamSubscription<bool> _isScanningSubscription;
  // Stream is the source of incoming data, eg scan results, start/stop scanning
  // listen() connects to the stream and returns a subscription, cancel() disconnects from the stream, 
  // otherwise the listener would stay active and cause memory leaks
  // late means the variable is initialized later, but before its first use
  // initialization is done in initState, not the declaration, because here mounted and setState cant be used yet
  // final means the variable can only be assigned once, 

  @override
  // before drawing the UI, request permissions and start listening to the scanner
  void initState() {
    super.initState();
    // flutter calls this method once, when the state is created, before the first build. 
    //It has to be first because the base class also has to initialize its state. 
    //mounted is true after initState and before dispose, it indicates if the widget is still in the widget tree, 
    //used to avoid calling setState on a disposed widget
    _requestPermissions();
    // requests the permissions, lack of await because initState cant be async, so the function starts in the background and the screen is drawn immediately

    // the list is updated in real time
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          _scanResults = results;
        });
      }
    });
    // with every new list from the BLE plugin (every new device or refresh), 3 things happen
    // - (results) {...} is an anonymous function, called with every new value
    // - mounted checks if the screen is still on the widget tree
    // the stream could send a value right after the screen is closed, then setState would throw an error
    // - setState changes the data and informs flutter that build() has to be called again
    // changin scanResults without setStae wouldn't be visible on the screen

    // the plugin tells us itself when the scan starts and stops (also after the timeout)
    _isScanningSubscription = FlutterBluePlus.isScanning.listen((scanning) {
      if (mounted) {
        setState(() {
          _isScanning = scanning;
        });
      }
    });
    // the same for the scanning state, 
    // the plugin informs when the scanning is over, also after 5-sec limit
    // the button returns from an hourglass to the search icon
  }

// cleaning
  @override
  void dispose() {
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    FlutterBluePlus.stopScan();
    super.dispose();
  }
  // the mirror to initState. called once when the screen dissapears forever
  // turns off the subscription and scanning because the drain battery
  // super.dispose() is at the end, opposite to initState, 
  // because the base class has to clean up its state after the subclass is done

  // ! Going to DeviceScreen does't call dispose(), the scanner stays int the background and comes back after pressing back

  // force permissions after app start
  // on Android 12+ location is not needed (BLUETOOTH_SCAN has neverForLocation),
  // on Android 11 and older bluetoothScan/Connect are granted automatically and location is needed
  // returns true if everything needed for scanning is allowed
  Future<bool> _requestPermissions() async {
    List<Permission> permissions = [Permission.bluetoothScan, Permission.bluetoothConnect];

    // location only on Android 11 (SDK 30) and older, newer ones don't need it for BLE
    if (Platform.isAndroid) {
      AndroidDeviceInfo info = await DeviceInfoPlugin().androidInfo;
      if (info.version.sdkInt <= 30) permissions.add(Permission.location);
    }

    // the answer for every permission, e.g. {bluetoothScan: granted, bluetoothConnect: denied}
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    return statuses.values.every((status) => status.isGranted);
  }

  // shown when the user refused a permission, with a button to the app settings
  // (after "don't ask again" the system window doesn't appear any more, only the settings help)
  void _showPermissionMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('The app needs the Bluetooth permission to find the EKG device'),
        action: SnackBarAction(label: 'SETTINGS', onPressed: openAppSettings),
      ),
    );
  }
  // - async / await / Future: Future is the result that will come later
  // await waits for is without blocking the screen, the function with await has to be async
  // Future<void> means the function at some point ends and doesnt return anything
  // - [...].request() requests the whole list at once, the system shows the permit? window
  // Which permissions are needed depends on the android version
  // Andoid 12+ only needs bluetoothScan and bluetoothConnect
  // Android 11- also needs location

  // function for scanning for devices
  Future<void> _startScan() async {
    // ask again, the user could have refused at the start (if all is allowed, no window appears)
    if (!await _requestPermissions()) {
      _showPermissionMessage();
      return;
    }
    setState(() => _hasScanned = true);

    try {
      // only devices advertising the EKG service are shown,
      // the scan stops by itself after 5 seconds
      await FlutterBluePlus.startScan(
        withServices: [ekgServiceUuid],
        timeout: const Duration(seconds: 5),
      );
      // - withSservices filters only devices that show the correct UUID, nothing else
      // - timeout stops the scan after 5 sec, scanning endlessly drains the battery and android limits too frequent scanning
      // - results dont come from this function but through the stream scanResults, listened to in initState
    } catch (e) {
      // e.g. bluetooth is turned off or permissions are missing
      debugPrint("Scan error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed, check if Bluetooth is on: $e')),
        );
      }
    }
  }
  // try/catch handles errors
  // debugPrint prints to the console, but only in debug mode
  // $e is string interpolation, the value of e is inserted into the string
  // ScaffoldMessenger.of(context).showSnackBar shows a bar at the bottom of the screen 
  // of(context) searches for the closest ScaffoldMessenger up th ewidget tree, created by MaterialApp
  // mounted is checked again, because after await the screen might have dissapeared already 

  @override
  // BUILD the UI
  Widget build(BuildContext context) {
    return Scaffold(    // basic visual skeleton
      appBar: AppBar(   // top bar
        title: const Text('Search for EKG Devices'),
        actions: [      // actions is the icon spot on the right side of AppBar.
          // kDebugMode is a constant: false in a release build, so this button is not even compiled in
          if (kDebugMode) // only true for flutter run, not flutter build apk --release
            IconButton(
              icon: const Icon(Icons.science),
              tooltip: 'Test signal (debug)',
              onPressed: () {
                FlutterBluePlus.stopScan();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const DeviceScreen.testSignal()),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Recordings',      // subtitle that shows up when held down
            onPressed: () => Navigator.of(context).push(      // same navigator push as CONNECT
              MaterialPageRoute(builder: (context) => const RecordingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      // Scaffold is the standard layout of the Material screen
      // with spot for the upper bar, content, floating buttons and SnackBar
      // empty list -> a hint in the middle of the screen instead of a blank page
      body: _scanResults.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _isScanning
                      ? 'Searching...'
                      : _hasScanned
                          ? 'No EKG device found.\nCheck if the ESP32 is powered on and try again.'
                          : 'Press the search button to find the ESP32_EKG device.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.builder(   // iterates over scan results and displays them in a list
              itemCount: _scanResults.length,    // number of items in the list
              itemBuilder: (context, index) {   // build each item in the list
                final result = _scanResults[index];
                // ListView.builder creates elements of the list layzily, only the ones visible on the screen
                // for a few elements it doesnt matter, but for a long list it does
                // itembuilder is called for every index  from 0 to itemCount-1
                String deviceName = result.device.platformName;
                if (deviceName.isEmpty) {
                  deviceName = "Unknown Device";
                }
                // platformName is the name from the advertising, in this case "ESP32_EKG"
                // the full name is visible thanks to setScanResponse(true) in the firmware
                return ListTile(                          // each item in the list in the form of a tile
                  leading: const Icon(Icons.bluetooth),   // icon on the left side of the tile
                  title: Text(deviceName),                // device name as the title of the tile
                  subtitle: Text(result.device.remoteId.toString()),  // device ID as the subtitle of the tile
                  // ListTIle is a standard list element =, icon on the left title, subtitle, and element on the right
                  // remoteId is the MAC address of the device
                  trailing: ElevatedButton(               // button on the right side of the tile
                    child: const Text('CONNECT'),         // button text
                    onPressed: () {                       // what happens when the button is pressed
                      FlutterBluePlus.stopScan();         // stop scanning before connect attempt
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => DeviceScreen(device: result.device),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      // - Before connecting we stop scanning, because simoultaneous scanning and connecting to multiple phones with android causes connection errors
      // - Navigator.push pushes a new screen on top, 
      // the back button takes it off and we return to the scanner
      // MaterialPageRoute adds transition animations
      // - DeviceScreen(device: result.device) passes the chosen device to the next window
      floatingActionButton: FloatingActionButton(   // button to start scanning (the floating button in the corner)
        onPressed: _isScanning ? null : _startScan,   // if scanning is in progress, disable the button
        child: Icon(_isScanning ? Icons.hourglass_empty : Icons.search),   // change the icon based on scanning state
      ),
    );
    // - condition ? A : B is a ternary operator, if true choose A, otherwise B
    // - onPresse: null, disables the button, it grays out the button so you can't activate 2 scans at once
    // - _startScan send the function itself, the flutter will run on click, with () it would activate immediately with drawing?
  }
}

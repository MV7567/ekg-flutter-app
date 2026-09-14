import 'package:flutter/material.dart';   // import ui stuff
import 'package:flutter_blue_plus/flutter_blue_plus.dart';    // import bluetooth stuff
import 'package:permission_handler/permission_handler.dart';  // import permission stuff

// main app engine
void main() {
  runApp(const EkgApp());
}

class EkgApp extends StatelessWidget {    // main app class
  const EkgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(   // basic visual skeleton
      title: 'EKG BLE',
      theme: ThemeData(primarySwatch: Colors.blue),   // theme color
      home: const ScannerScreen(),    // main screen
    );
  }
}

// scanner, stateful widget, because we need to update the UI when scanning
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

// state class for the scanner screen
class _ScannerScreenState extends State<ScannerScreen> {
  bool isScanning = false;              // flag to indicate if scanning is in progress
  List<ScanResult> scanResults = [];    // list to hold scan results

  @override
  // before drawing the UI, request permissions for bluetooth and location
  void initState() {
    super.initState();
    _requestPermissions();
  }

  // force permissions after app start
  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  // function for scanning for devices
  void startScan() async {
    setState(() {   // update the flag to true and clear previous results
      isScanning = true;
      scanResults.clear();
    });

    // start the antena for 5 sec, .listen waits for results and updates the list immediately 
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    // the list is updated in real time
    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        scanResults = results;
      });
    });

    // waits 5 seconds, updates the flag to false and stops the scan
    await Future.delayed(const Duration(seconds: 5));
    setState((){
      isScanning = false;
    });
    FlutterBluePlus.stopScan();
  }

  @override
  // build the UI
  Widget build(BuildContext context) {
    return Scaffold(    // basic visual skeleton
      appBar: AppBar(   // top bar
        title: const Text('Search for EKG Devices'),
        backgroundColor: Colors.blueAccent,
      ),
      body: ListView.builder(   // iterates over scan results and displays them in a list
        itemCount: scanResults.length,    // number of items in the list
        itemBuilder: (context, index) {   // build each item in the list
          final result = scanResults[index];
          // attempt to read the name, some device don't advertise it, then display ID instead
          String deviceName = result.device.platformName;
          if (deviceName.isEmpty) {
            deviceName = "Unknown Device";
          }
          return ListTile(    // each item in the list in the form of a tile
            leading: const Icon(Icons.bluetooth),   // icon on the left side of the tile
            title: Text(deviceName),                // device name as the title of the tile
            subtitle: Text(result.device.remoteId.toString()),  // device ID as the subtitle of the tile
            trailing:ElevatedButton(        // button on the right side of the tile
              child: const Text('CONNECT'), // button text
              onPressed: () {   // what happens when the button is pressed
                // add connect logic 
                print("Pressed connect with: $deviceName");
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(   // button to start scanning (the floating button in the corner)
        onPressed: isScanning ? null : startScan,   // if scanning is in progress, disable the button
        child: Icon(isScanning ? Icons.hourglass_empty : Icons.search), // change the icon based on scanning state
      ),
    );
  }
}
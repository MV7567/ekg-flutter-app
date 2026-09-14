import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const EkgApp());
}

class EkgApp extends StatelessWidget {
  const EkgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EKG BLE',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ScannerScreen(),
    );
  }
}

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool isScanning = false;
  List<ScanResult> scanResults = [];

  @override
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
    setState(() {
      isScanning = true;
      scanResults.clear();
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        scanResults = results;
      });
    });

    await Future.delayed(const Duration(seconds: 5));
    setState((){
      isScanning = false;
    });
    FlutterBluePlus.stopScan();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search for EKG Devices'),
        backgroundColor: Colors.blueAccent,
      ),
      body: ListView.builder(
        itemCount: scanResults.length,
        itemBuilder: (context, index) {
          final result = scanResults[index];
          // attempt to read the name, some device don't advertise it, then display ID instead
          String deviceName = result.device.platformName;
          if (deviceName.isEmpty) {
            deviceName = "Unknown Device";
          }
          return ListTile(
            leading: const Icon(Icons.bluetooth),
            title: Text(deviceName),
            subtitle: Text(result.device.remoteId.toString()),
            trailing:ElevatedButton(
              child: const Text('CONNECT'),
              onPressed: () {
                // add connect logic 
                print("Pressed connect with: $deviceName");
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isScanning ? null : startScan,
        child: Icon(isScanning ? Icons.hourglass_empty : Icons.search),
      ),
    );
  }
}
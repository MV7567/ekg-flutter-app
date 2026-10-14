import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:path_provider/path_provider.dart';

// device screen, stateful widget, because we need to update the UI when connecting
class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({super.key, required this.device});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;

  final String targetServiceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String targetCharacteristicUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  IOSink? _fileSink;
  String _savedFilePath = "";

  // object to control the data stream
  StreamSubscription<List<int>>? _bleSubscription;

  @override
  void initState() {
    super.initState();
    _initFileAndConnect();
  }
  Future _initFileAndConnect() async {
    await _setupDataFile();
    await _connectToDevice();
  }

  Future _setupDataFile() async {
    try {
      // get the downloads directory for saving the data file
      List? directories = await getExternalStorageDirectories(type: StorageDirectory.downloads);
      
      if (directories != null && directories.isNotEmpty) {
        Directory directory = directories.first; // usually the first directory is the downloads one
        
        // create a new file with a timestamp in the name
        String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        File file = File('${directory.path}/ekg_data_$timestamp.txt');

        // open the file in write mode and store the sink for writing data later
        _fileSink = file.openWrite(mode: FileMode.write);

        setState(() {
          _savedFilePath = file.path;
        });

        debugPrint("==================================================");
        debugPrint("DATA FILE WILL BE SAVED IN:");
        debugPrint(file.path);
        debugPrint("==================================================");
      }
    } catch (e) {
      debugPrint("Error setting up data file: $e");
    }
  }

  Future _connectToDevice() async {
    // listen to the connection state (connected, disconnected, connecting, disconnecting)
    widget.device.connectionState.listen((state) async {
      if (mounted) {
        setState(() {
          _connectionState = state;
        });
      }

      // when connected, discover services
      if (state == BluetoothConnectionState.connected) {
        await _discoverAndSubscribe();
      }
    });

    // attempt to connect to the esp32
    try {
      await widget.device.connect();
    } catch (e) {
      debugPrint("Connection error: $e");
    }
  }

  // discover services and subscribe to the target characteristic
  Future _discoverAndSubscribe() async {
    try {
      List services = await widget.device.discoverServices();

      for (var service in services) {
        // searching for the target service and characteristic
        if (service.uuid.toString() == targetServiceUuid) {
          for (var characteristic in service.characteristics) {
            // if the target characteristic is found, subscribe to it
            if (characteristic.uuid.toString() == targetCharacteristicUuid) {
              debugPrint("Found target characteristic, subscribing...");

              // enable notifications for the characteristic
              await characteristic.setNotifyValue(true);

              // listen to the characteristic's value stream and process incoming data
              _bleSubscription = characteristic.lastValueStream.listen((value) {
                if (value.isNotEmpty) {
                  _processEkgData(value);
                }
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Service discovery error: $e");
    }
  }

  // function to process the EKG data received from the characteristic
  void _processEkgData(List data) {
    // if the file sink is not initialized, return early
    if (_fileSink == null) return;

    // check if the received data is 20 bytes long (10 samples)
    if (data.length == 20) {
      for (int i = 0; i < data.length; i += 2) {
        int highByte = data[i];
        int lowByte = data[i + 1];

        // combine the two bytes into a single 16-bit integer
        int ekgValue = (highByte << 8) | lowByte;

        // convert to negative values (if the amplifier outputs them)
        if (ekgValue > 32767) {
          ekgValue -= 65536;
        }

        _fileSink?.writeln(ekgValue); // write the EKG value to the file
        //debugPrint("EKG value: $ekgValue");
      }
    }
  }

  @override 
  void dispose() {
    // new closing order
    // 1. Cancel the BLE subscription
    _bleSubscription?.cancel();
    // 2. Close the file sink
    _fileSink?.close(); // close the file sink when the widget is disposed, ensure its saved properly
    _fileSink = null; // set as empty
    // 3. Disconnect the device
    widget.device.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.platformName.isEmpty ? "Unknown" : widget.device.platformName),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _connectionState.name.toUpperCase(),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: _connectionState == BluetoothConnectionState.connected ? Colors.green : Colors.red,
                ),
              ),
              const SizedBox(height: 30),
              if (_connectionState == BluetoothConnectionState.connected) ...[
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                const Text('Receiving and saving data to file...', 
                  style: TextStyle(fontSize: 16), textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text('Path:\n$_savedFilePath', 
                  style: const TextStyle(fontSize: 12, color: Colors.grey), textAlign: TextAlign.center),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
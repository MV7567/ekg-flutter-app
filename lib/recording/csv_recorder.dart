import 'dart:io';                                   // File, FileMode, IOSink
import 'package:flutter/foundation.dart';           // debugPrint
import 'package:flutter/services.dart';             // MethodChannel (android interaction)
import 'package:path_provider/path_provider.dart';  // extra app folder
import '../ekg_config.dart';                        // sampleRateHz, pgaGain, millivoltsPerLsb
// foundation is a small basic flutter library, we dont need material because this doesnt do widgets

// writes one recording into a CSV file:
//   open() -> writeSample() for every sample -> close()
// a new CsvRecorder.open() call starts a new file
class CsvRecorder {
  // public Download folder, visible in the phone's file manager
  // (works on Android 11+, older versions fall back to the app folder)
  static const String publicDownloadPath = "/storage/emulated/0/Download";
  // will be useful in saved recording screen 

  // Android only indexes files written directly to Download from time to time,
  // so the file is registered right away through MainActivity.kt
  // version of the file layout (header + columns), written in the header,
  // so the recordings screen can still read old files if the columns change one day
  static const int formatVersion = 1;

  static const MethodChannel _mediaScanner = MethodChannel('ecg_ble_app/media_scanner');
  // connection between dart and android native code, the channel name is arbitrary but must match the one in MainActivity.kt

  IOSink? _sink;
  String _filePath = "";
  // pipe to the file, throw text into it (writeln) and it's saved to the file part by part in the background, 
  //each line separately would be too slow, null means the file isnt open

  // true between open() and close()
  bool get isOpen => _sink != null;
  // we get isOpen from _sink for consistency, so they never differ

  // path of the current or the last file, "" before the first recording
  String get filePath => _filePath;

  // creates a new file with the header, returns false if no folder is writable
  Future<bool> open({required String deviceName}) async {
    // readable timestamp for the file name, e.g. ekg_2026-10-21_14-30-05.csv
    // one "now" for the file name and the header, so they always show the same time
    DateTime start = DateTime.now();
    String startIso = start.toIso8601String().split('.').first;   // 2026-10-21T14:30:05
    String timestamp = startIso.replaceAll('T', '_').replaceAll(':', '-'); // : is forbidden in file names
    String baseName = 'ekg_$timestamp';   // without .csv, a _2, _3... can still be added

    // header describing the data, lines starting with # are comments
    String header =
        "# EKG recording, device: $deviceName\n"
        "# format: $formatVersion\n"
        "# start: $startIso\n"
        "# sample rate: $sampleRateHz Hz, gain: $pgaGain, 1 LSB = ${(millivoltsPerLsb * 1000).toStringAsFixed(2)} uV\n"
        "# lost BLE packets are skipped, the sample numbers jump over the gap\n"
        "sample,time_s,raw,mV\n";

    // 1. try the public Download folder
    File? file = await _tryCreateFile(publicDownloadPath, baseName, header);

    // 2. if not allowed, use the app's own folder (Android/data/com.example.ecg_ble_app/files/Download)
    if (file == null) {
      try {
        List<Directory>? directories =
            await getExternalStorageDirectories(type: StorageDirectory.downloads);
        if (directories != null && directories.isNotEmpty) {
          file = await _tryCreateFile(directories.first.path, baseName, header);
        }
      } catch (e) {
        debugPrint("Error getting app storage directory: $e");
      }
    }

    if (file == null) return false;

    // open the file in append mode (header is already written) and keep the sink for the samples
    _sink = file.openWrite(mode: FileMode.append);
    _filePath = file.path;

    debugPrint("==================================================");
    debugPrint("DATA FILE WILL BE SAVED IN:");
    debugPrint(file.path);
    debugPrint("==================================================");
    return true;
  }

  // one line: sample number, time, raw value, value in mV
  void writeSample(int sampleIndex, int rawValue) {
    _sink?.writeln(csvLine(sampleIndex, rawValue));
  }

  // the text of one line (without the new line), static so it can be tested without a file
  static String csvLine(int sampleIndex, int rawValue) {
    double timeS = sampleIndex / sampleRateHz;
    double millivolts = rawValue * millivoltsPerLsb;
    return "$sampleIndex,${timeS.toStringAsFixed(3)},$rawValue,${millivolts.toStringAsFixed(4)}";
  }
  // one csv line
  // / division by sampleRateHz gives the time in seconds, to 3 decimal places is enough for 1 kHz
  // time has 3 decimal places, because step 4ms
  // mV has 4 decimal places, step is 0,0061 mV 
  // writeln is write + new line
  // ?. : if the file is closed (null) the line is skipped without errror 
  // toStringAsFixed always uses a . as the decimal separator regardless of language

  // writes the rest of the data, closes the file and makes it visible in the file manager
  // safe to call more than once
  // returns false if writing failed (e.g. phone memory full, file deleted during the recording),
  // then the file may be incomplete
  Future<bool> close() async {
    IOSink? sink = _sink;
    _sink = null;   // set first, so writeSample() does nothing from now on
    if (sink == null) return true;   // nothing open, nothing could fail
    // take the value and then reset it

    bool ok = true;
    try {
      // IOSink reports write errors only here, writeln() itself never throws
      await sink.flush();
      await sink.close();
    } catch (e) {
      debugPrint("Error while closing $_filePath: $e");
      ok = false;
    }
    // registered also after an error, the part written so far is still in the file
    await updateMediaStore(_filePath);
    return ok;
    // flush pushes to the file whatever waits in the sink buffer
    // close closes the file, after that the sink is invalid
    // the file is registered in MediaStore, after closing when its ready, so its visible in the file manager
  }

  // writes the header to check if the folder is writable, returns null if it isn't
  Future<File?> _tryCreateFile(String folder, String baseName, String header) async {
    try {
      File file = await _newFile(folder, baseName);
      await file.writeAsString(header, mode: FileMode.write, flush: true);
      return file;
    } catch (e) {
      debugPrint("Cannot write to $folder: $e");
      return null;
    }
  }
  // File(path) doesnt create anything yet, its just the address. 
  // writeAsString creates the file and writes the header (also checks the permision to write in the folder)

  // ekg_..._14-30-05.csv, or ekg_..._14-30-05_2.csv, _3... if it already exists
  // (two recordings started in the same second), FileMode.write would otherwise overwrite the first one
  Future<File> _newFile(String folder, String baseName) async {
    File file = File('$folder/$baseName.csv');
    int number = 2;
    while (await file.exists()) {
      file = File('$folder/${baseName}_$number.csv');
      number++;
    }
    return file;
  }

  // static and public: also used after deleting a file, a scan of a missing file removes its MediaStore entry
  static Future<void> updateMediaStore(String path) async {
    if (!Platform.isAndroid || path.isEmpty) return;
    try {
      await _mediaScanner.invokeMethod('scanFile', {'path': path});
    } catch (e) {
      debugPrint("Media scan error: $e");
    }
  }
  // invokeMethod sends messages through the channel to the android code
  // iphones dont have MediaStore its visible immediately
  // try/catch, if the registration fails the file still exists, the file manager will show it later when it scans the folders  
}

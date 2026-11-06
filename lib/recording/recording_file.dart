import 'dart:convert';                              // utf8
import 'dart:io';                                   // File, Directory, RandomAccessFile
import 'package:flutter/foundation.dart';           // debugPrint, Float32List
import 'package:path_provider/path_provider.dart';  // the app's own folder
import '../ekg_config.dart';                        // sampleRateHz, millivoltsPerLsb
import '../filters/biquad_filter.dart';             // EkgDisplayFilter
import 'csv_recorder.dart';                         // publicDownloadPath

// information about one saved recording, read from its header and last line,
// without loading all the samples (a 10 min recording has 150 000 lines)
class RecordingInfo {
  RecordingInfo({
    required this.file,
    required this.start,
    required this.deviceName,
    required this.formatVersion,
    required this.sizeBytes,
    required this.duration,
  });

  final File file;
  final DateTime? start;       // null if neither the header nor the file name has a date
  final String deviceName;     // "" if unknown (old files)
  final int formatVersion;     // 0 = old file without "# format:" line
  final int sizeBytes;
  final Duration duration;

  String get fileName => file.uri.pathSegments.last;

  // all recordings from the folders CsvRecorder writes to, newest first (download folder and the apps own folder)
  static Future<List<RecordingInfo>> listAll() async {
    List<String> folders = [CsvRecorder.publicDownloadPath];
    try {
      List<Directory>? appFolders =
          await getExternalStorageDirectories(type: StorageDirectory.downloads);
      if (appFolders != null && appFolders.isNotEmpty) folders.add(appFolders.first.path);
    } catch (e) {
      debugPrint("No app storage folder: $e");
    }
    // each folder has its own try/catch, if one is unavailable the other works

    List<RecordingInfo> recordings = [];
    for (String folder in folders) {
      try {
        await for (FileSystemEntity entity in Directory(folder).list()) {
          if (entity is File && isRecordingFileName(entity.uri.pathSegments.last)) {
            recordings.add(await load(entity));
          }
        }
      } catch (e) {
        // folder missing or not readable, the other folder may still work
        debugPrint("Cannot list $folder: $e");
      }
    }

    // newest first, files without a date at the end
    recordings.sort((a, b) {
      if (a.start == null) return 1;
      if (b.start == null) return -1;
      return b.start!.compareTo(a.start!);
    });
    return recordings;
  }

  // reads only the beginning (header, first 1024 bytes) and the end (last sample, last 256 bytes) of the file
  static Future<RecordingInfo> load(File file) async {
    int size = await file.length();
    RandomAccessFile raf = await file.open();   // Random access file, unlike readAsString doesnt read the whole file, but any position
    try {
      String head = await _readText(raf, 0, 1024);
      String tail = await _readText(raf, size > 256 ? size - 256 : 0, 256);

      String name = file.uri.pathSegments.last;
      List<String> headLines = const LineSplitter().convert(head);

      return RecordingInfo(
        file: file,
        start: parseStart(headLines, name),
        deviceName: parseDeviceName(headLines),
        formatVersion: parseFormatVersion(headLines),
        sizeBytes: size,
        duration: durationFromLastLines(const LineSplitter().convert(tail)),
      );
    } finally {
      await raf.close();   // file always closes, also after an error
    }
  }

  static Future<String> _readText(RandomAccessFile raf, int position, int length) async {
    await raf.setPosition(position);                    // jump to whichever place in the file
    List<int> bytes = await raf.read(length);
    return utf8.decode(bytes, allowMalformed: true);   // a cut letter at the edge is not an error
  }
  // the loop goes from the end and takes the first line with >=3 columns and a number in the first one, the sample number take sinto consideration lost packets

  // all samples of the file in mV, filtered like the live chart,
  // reads the whole file, so it runs in a background isolate (see compute() in the view screen),
  // static because an isolate can only start a static or top-level function
  static Float32List loadFilteredMillivolts(String path) {  // reads the whole file, puts it through the same filter as in a live measurement 
    List<String> lines = File(path).readAsLinesSync();   // sync is ok, this is not the UI thread
    Float32List millivolts = parseMillivolts(lines);
    EkgDisplayFilter filter = EkgDisplayFilter(sampleRateHz.toDouble());
    for (int i = 0; i < millivolts.length; i++) {
      millivolts[i] = filter.process(millivolts[i]);
    }
    return millivolts;
  }

  // ---- pure functions below: no files, so they can be tested ----

  // "sample,time_s,raw,mV" lines -> mV values, the index in the list = the sample number
  // - header (#...), column names and cut lines are skipped
  // - mV column if it exists, otherwise raw x LSB
  // - lost packets: the sample number jumps, the gap is filled with the last value
  //   (a flat line), so the time axis stays correct
  static Float32List parseMillivolts(List<String> lines) {  
    // every line sample, time_s, raw, mV are changed into mV value, list position is the sample number
    List<double> values = [];
    for (String line in lines) {
      List<String> columns = line.split(',');
      if (columns.length < 3) continue;           // #, header, empty or cut line skips
      int? sample = int.tryParse(columns[0]);
      if (sample == null) continue;               // "sample,time_s,..." column names
      double? mv = columns.length >= 4 ? double.tryParse(columns[3]) : null;
      if (mv == null) {
        int? raw = int.tryParse(columns[2]);
        if (raw == null) continue;
        mv = raw * millivoltsPerLsb;
      } // takes a mV column if possible, if there isnt it calcs raw x millivoltsPerLsb
      if (sample < values.length) continue;       // repeated or older sample number
      double fill = values.isEmpty ? mv : values.last;
      while (values.length < sample) {
        values.add(fill);                         // gap from lost packets
      }   // lost packets: after sample 0, sample 3 comes immediately, so samples 1 and 2 receive the last 2 values so there is a brief flat line on the chart
      values.add(mv);
    }
    return Float32List.fromList(values);   // 4 bytes per sample instead of 8, like in EkgBuffer
  }

  // ekg_2026-10-21_14-30-05.csv, ekg_..._2.csv
  static bool isRecordingFileName(String name) =>
      name.startsWith('ekg_') && name.endsWith('.csv');
      // only files with ekg and csv

  // "# EKG recording, device: ESP32_EKG" -> "ESP32_EKG"
  static String parseDeviceName(List<String> headerLines) {
    for (String line in headerLines) {
      int i = line.indexOf('device:');
      if (line.startsWith('#') && i >= 0) return line.substring(i + 'device:'.length).trim();
    }
    return '';
  }

  // "# format: 1" -> 1, no such line -> 0 (files from before the format line existed)
  static int parseFormatVersion(List<String> headerLines) {
    for (String line in headerLines) {
      if (line.startsWith('# format:')) {
        return int.tryParse(line.substring('# format:'.length).trim()) ?? 0;
      }
    }
    return 0;
  }

  // "# start: 2026-10-21T14:30:05" from the header,
  // for old files the date is taken from the file name ekg_2026-10-21_14-30-05.csv
  static DateTime? parseStart(List<String> headerLines, String fileName) {
    for (String line in headerLines) {
      if (line.startsWith('# start:')) {
        DateTime? start = DateTime.tryParse(line.substring('# start:'.length).trim());
        if (start != null) return start;
      }
    }
    RegExpMatch? m = RegExp(r'ekg_(\d{4}-\d{2}-\d{2})_(\d{2})-(\d{2})-(\d{2})').firstMatch(fileName);
    if (m == null) return null;
    return DateTime.tryParse('${m[1]}T${m[2]}:${m[3]}:${m[4]}');
  }

  // the first column of the last complete data line is the sample number,
  // sample numbers include the lost packets, so this is the real length of the recording
  static Duration durationFromLastLines(List<String> tailLines) {
    // from the end: the very last line may be cut (file still being written, or the tail
    // started in the middle of a line), so take the last line that parses
    for (int i = tailLines.length - 1; i >= 0; i--) {
      List<String> columns = tailLines[i].split(',');
      if (columns.length < 3) continue;   // cut line or empty line
      int? sample = int.tryParse(columns[0]);
      if (sample != null) {
        return Duration(milliseconds: ((sample + 1) * 1000 / sampleRateHz).round());
      }
    }
    return Duration.zero;   // only the header, no samples
  }
}

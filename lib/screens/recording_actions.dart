import 'dart:io';                               // File
import 'package:flutter/foundation.dart';      // Float32List
import 'package:flutter/services.dart';        // rootBundle (the font files)
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';   // temporary folder for the PDF
import 'package:pdf/widgets.dart' as pw;       // pw.Font
import 'package:share_plus/share_plus.dart';   // the Android share sheet
import '../ekg_config.dart';                   // sampleRateHz
import '../recording/pdf_report.dart';
import '../af_detector.dart';
import '../rhythm_analysis.dart';
import '../rr_stats.dart';
import '../artifact_detector.dart';            // Artifact
import '../recording/csv_recorder.dart';       // updateMediaStore
import '../recording/recording_file.dart';
import '../l10n/app_localizations.dart';
import 'recordings_screen.dart';               // formatStart

// the calibration check of a test signal recording, for the view screen and the PDF
String testSignalResult(AppLocalizations t, double measuredMv) {
  double expected = RecordingInfo.expectedTestPeakToPeakMv;
  double errorPercent = (measuredMv / expected - 1) * 100;
  String sign = errorPercent >= 0 ? '+' : '';
  return t.testSignalResult(expected.toStringAsFixed(3), measuredMv.toStringAsFixed(3),
      '$sign${errorPercent.toStringAsFixed(1)} %');   // a no-break space: "%" never alone in the next line
}

// share and delete, used by the list and by the view screen,
// so both screens do exactly the same

// opens the system share window (Gmail, Drive, Bluetooth, ...) with the CSV file attached
// several recordings at once (e.g. the results of a test series), one share window with all the files
// no subject: with one subject Google Drive would name every file the same, without it the files
// keep their own names (ekg_2026-11-23_21-30-05.csv), with .csv
Future<void> shareRecordings(BuildContext context, List<RecordingInfo> recordings) async {
  if (recordings.isEmpty) return;
  if (recordings.length == 1) return shareRecording(context, recordings.first);
  AppLocalizations t = AppLocalizations.of(context);
  try {
    await SharePlus.instance.share(ShareParams(
      files: [for (RecordingInfo r in recordings) XFile(r.file.path, mimeType: 'text/csv')],
    ));
  } catch (e) {
    debugPrint("Share error: $e");
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.shareError('$e'))));
    }
  }
}

Future<void> shareRecording(BuildContext context, RecordingInfo recording) async {
  // texts taken now, while the screen surely exists (before any await)
  AppLocalizations t = AppLocalizations.of(context);
  try {
    await SharePlus.instance.share(ShareParams(
      files: [XFile(recording.file.path, mimeType: 'text/csv')],
      subject: t.shareSubject(RecordingsScreen.formatStart(recording.start, t)),  // e-mail subject
    ));
  } catch (e) {
    debugPrint("Share error: $e");
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.shareError('$e'))));
    }
  }
}

// a dialog to write or change the note of a recording ("rest", "after running"),
// saves it in the file, returns the new note, null = cancelled or not saved
Future<String?> editRecordingNote(BuildContext context, RecordingInfo recording, String currentNote) async {
  AppLocalizations t = AppLocalizations.of(context);
  String? note = await showDialog<String>(
    context: context,
    builder: (context) => NoteDialog(currentNote: currentNote),
  );
  if (note == null) return null;   // cancelled
  note = CsvRecorder.cleanNote(note);
  if (note == currentNote) return null;   // nothing changed, nothing to write

  try {
    await CsvRecorder.appendNote(recording.file.path, note);
    return note;
  } catch (e) {
    debugPrint("Note save error: $e");
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.noteSaveError('$e'))));
    }
    return null;
  }
}

// makes the PDF report of a loaded recording and opens the share window with it
// (e-mail, Drive, a printer app, "save to files"...)
// the PDF goes to the temporary folder: it can be made again any time from the CSV
Future<void> shareReport(
  BuildContext context,
  RecordingInfo recording, {
  required String note,
  required Float32List millivolts,
  required List<int> beats,
  required List<int> events,
  List<Artifact> artifacts = const [],
  required RrStats? stats,
  RhythmAnalysis? rhythm,
  AfDetector? af,
  double? testPeakToPeakMv,
}) async {
  AppLocalizations t = AppLocalizations.of(context);
  try {
    // the fonts with Polish letters, from the assets (see pubspec.yaml)
    pw.Font regular = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
    pw.Font bold = pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
    Uint8List bytes = await PdfReport.build(
      t: t,
      regular: regular,
      bold: bold,
      start: recording.start,
      deviceName: recording.deviceName,
      note: note,
      millivolts: millivolts,
      beats: beats,
      events: events,
      artifacts: artifacts,
      testPeakToPeakMv: testPeakToPeakMv,
      stats: stats,
      rhythm: rhythm,
      af: af,
      sampleRateHz: sampleRateHz,
    );
    // ekg_2026-11-12_16-25-25.csv -> ekg_2026-11-12_16-25-25_report.pdf
    String name = recording.fileName.replaceAll(RegExp(r'\.csv$'), '_report.pdf');
    File file = File('${(await getTemporaryDirectory()).path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      subject: t.shareSubject(RecordingsScreen.formatStart(recording.start, t)),
    ));
  } catch (e) {
    debugPrint("Report error: $e");
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.reportError('$e'))));
    }
  }
}

// asks first, then deletes, returns true if the file was deleted
Future<bool> confirmAndDeleteRecording(BuildContext context, RecordingInfo recording) async {
  AppLocalizations t = AppLocalizations.of(context);
  bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(t.deleteTitle),
      content: Text('${RecordingsScreen.formatStart(recording.start, t)}\n${recording.fileName}\n\n'
          '${t.deleteWarning}'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(t.commonCancel)),   // cancel button
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(foregroundColor: const Color.fromARGB(255, 238, 64, 52)),     // delete button
          child: Text(t.deleteButton),
        ),
      ],
    ),
  );
  // null = closed by tapping outside the dialog or with the back button, same as cancel
  if (confirmed != true) return false;    // != true because both false and null means dont delete

  try {
    await recording.file.delete();    // removes the file
    // without this the file manager / PC over USB could still show the deleted file
    await CsvRecorder.updateMediaStore(recording.file.path);    // scans the path that doesnt exist anymore, deletes the record from MediaStore, 
    // without it the file manager could still show a ghost file, that's why it's static and public
    return true;
  } catch (e) {
    debugPrint("Delete error: $e");
    if (context.mounted) {    // checks if the screen sitll exists after await
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.deleteError('$e')))); // show the error in the snackbar
    }
    return false;
  }
}

// the note dialog owns its text controller and frees it in dispose(), i.e. only when the dialog
// is really gone; freeing it right after showDialog() returned was too early: the closing
// animation still draws the TextField and Flutter stopped with a red "_dependents.isEmpty" screen
class NoteDialog extends StatefulWidget {
  const NoteDialog({super.key, required this.currentNote});

  final String currentNote;

  @override
  State<NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<NoteDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.currentNote);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations t = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(t.noteDialogTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,                                   // the keyboard opens at once
        maxLength: CsvRecorder.maxNoteLength,              // a counter "12/80" under the field
        decoration: InputDecoration(hintText: t.noteHint),
        onSubmitted: (text) => Navigator.of(context).pop(text),   // Enter = save
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(t.commonCancel)),
        TextButton(onPressed: () => Navigator.of(context).pop(_controller.text), child: Text(t.commonSave)),
      ],
    );
  }
}

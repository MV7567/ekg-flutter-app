import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';   // the Android share sheet
import '../recording/csv_recorder.dart';       // updateMediaStore
import '../recording/recording_file.dart';
import '../l10n/app_localizations.dart';
import 'recordings_screen.dart';               // formatStart

// share and delete, used by the list and by the view screen,
// so both screens do exactly the same

// opens the system share window (Gmail, Drive, Bluetooth, ...) with the CSV file attached
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

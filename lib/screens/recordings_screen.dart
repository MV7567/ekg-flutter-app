import 'package:flutter/material.dart';
import '../recording/recording_file.dart';
import 'recording_actions.dart';
import 'recording_view_screen.dart';

// list of the saved CSV recordings, newest first
class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();

  // ---- pure functions for the list texts, static so they can be tested ----

  // 2026-11-04 14:30:05, null -> "Unknown date"
  static String formatStart(DateTime? start) {
    if (start == null) return 'Unknown date';
    String two(int n) => n.toString().padLeft(2, '0');  // changes 9 to 09
    return '${start.year}-${two(start.month)}-${two(start.day)} '
        '${two(start.hour)}:${two(start.minute)}:${two(start.second)}';
  }

  // 65 s -> "1:05", 3725 s -> "1:02:05"
  static String formatDuration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    int hours = d.inHours;
    int minutes = d.inMinutes % 60;   // minutes without full hours, hours show up when they appear
    int seconds = d.inSeconds % 60;
    return hours > 0 ? '$hours:${two(minutes)}:${two(seconds)}' : '$minutes:${two(seconds)}';
  }

  // 812 -> "812 B", 2048 -> "2.0 kB", 3 500 000 -> "3.3 MB"
  static String formatSize(int bytes) {   // counts in steps every 1024, so 3 500 000 B is 3.3 MB
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} kB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  late Future<List<RecordingInfo>> _recordings;

  @override
  void initState() {
    super.initState();
    _recordings = RecordingInfo.listAll();
  }

  // reads the folders again, used by pull-to-refresh and after a delete (R4)
  Future<void> _refresh() async {
    Future<List<RecordingInfo>> next = RecordingInfo.listAll();
    setState(() => _recordings = next);
    await next;   // the refresh spinner stays until the list is read
  }

  // the view screen returns true when the recording was deleted there
  Future<void> _open(RecordingInfo r) async {
    bool? deleted = await Navigator.of(context).push<bool>(   // the list awaits
      MaterialPageRoute(builder: (context) => RecordingViewScreen(recording: r)),
    );
    if (deleted == true && mounted) _refresh();
  }
  // push returns a Future, which ends with pop, value parsed to pop
  // exiting with the back arrow gives null so the list refreshes only with a normal deletion

  Future<void> _delete(RecordingInfo r) async {
    if (await confirmAndDeleteRecording(context, r) && mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recordings')),
      body: FutureBuilder<List<RecordingInfo>>(     // list read in the background, listAll() returns Future because file reading is in progress, 
        future: _recordings,                        // in initState it saves this Future in _recordings, Future builder draws the screen depending on its state
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {   // spinning around
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {                  // error text obv
            return Center(child: Text('Cannot read recordings:\n${snapshot.error}',
                textAlign: TextAlign.center));
          }
          List<RecordingInfo> recordings = snapshot.data!;  // ready list
          // Future is created in initState not in build, because is called many times
          // then files would be read with every redraw

          return RefreshIndicator(
            onRefresh: _refresh,    // creates a new Future, puts it in setState, 
            // and awaits for the refresh wheel to dissappears after reading the list
            // an empty list is also ListView with one text, because RefreshIndicator only works on something that can be scrolled,
            // the same function will be used to refresh the list after file removal
            child: recordings.isEmpty
                // ListView also for the empty text, RefreshIndicator needs something scrollable
                ? ListView(children: const [
                    Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No recordings yet.\nStart a recording on the device screen.',
                          textAlign: TextAlign.center),
                    ),
                  ])
                : ListView.builder(
                    itemCount: recordings.length,
                    itemBuilder: (context, index) {
                      RecordingInfo r = recordings[index];
                      String device = r.deviceName.isEmpty ? '' : '  ·  ${r.deviceName}';
                      return ListTile(
                        leading: const Icon(Icons.monitor_heart),
                        title: Text(RecordingsScreen.formatStart(r.start)),
                        subtitle: Text('${RecordingsScreen.formatDuration(r.duration)}  ·  '
                            '${RecordingsScreen.formatSize(r.sizeBytes)}$device'),
                        onTap: () => _open(r),
                        // ⋮ menu on the right
                        trailing: PopupMenuButton<String>(  // each position has value (share/delete)
                          onSelected: (action) => action == 'share' ? shareRecording(context, r) : _delete(r),   // decides what to do 
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'share', child: ListTile(  // ListTile so there can be an icon next to text
                                leading: Icon(Icons.share), title: Text('Share'))),
                            PopupMenuItem(value: 'delete', child: ListTile(
                                leading: Icon(Icons.delete, color: Colors.red), title: Text('Delete'))),
                          ],
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

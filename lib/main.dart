import 'package:flutter/material.dart';   // import ui stuff
import 'screens/scanner_screen.dart';     // import scanner screen

// main entry point of the app
void main() {
  runApp(const EkgApp());
}

// main app widget, stateless because it doesn't need to update the UI
class EkgApp extends StatelessWidget {
  const EkgApp({super.key});

  @override
  // build method to build the UI
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EKG App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ScannerScreen(),
    );
  }
}
import 'package:flutter/material.dart';   // import ui stuff
import 'screens/scanner_screen.dart';     // import scanner screen

// main entry point of the app
void main() {
  runApp(const EkgApp());
}
// main is the first function ran by the app. runApp takes a widget and makes it the app screen
// const means the object is created once because it doesnt have any changing data, performance optimization

// main app widget, stateless because it doesn't need to update the UI
// stateless widgets dont have their own state, always looks the same for the same input
class EkgApp extends StatelessWidget {
  const EkgApp({super.key});
// super key passes an optional key to the parent class, used for widget tree optimization

  @override
  // build method to build the UI
  // build describes the look of the widget
  // @override means overriding the method from StatelessWidget, context is the spot of widget in the tree, used to get theme and localization info
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EKG App',
      // Material 3 ignores primarySwatch, the colors come from the colorScheme
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
      home: const ScannerScreen(),
    );
    // MaterialApp is the skeleton of the app, manages navigation (Navigator), theme, language
    // title is the shown app name
    // home is the homescreen of the app
  }
}

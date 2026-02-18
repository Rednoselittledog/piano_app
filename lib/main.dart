import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'rhythm_app/rhythm_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const RhythmApp());
}

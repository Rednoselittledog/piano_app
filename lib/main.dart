import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'rhythm_app/rhythm_app.dart';

void main() async {
  print('🚀 [MAIN] Starting app...');
  WidgetsFlutterBinding.ensureInitialized();
  print('✅ [MAIN] WidgetsFlutterBinding initialized');

  // Set landscape orientation BEFORE running the app
  print('🔄 [MAIN] Setting orientation...');
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  print('✅ [MAIN] Orientation set');

  print('🎯 [MAIN] Running app...');
  runApp(const RhythmApp());
  print('✅ [MAIN] App started');
}

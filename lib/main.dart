import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PianoDetector(),
    ));

class PianoDetector extends StatefulWidget {
  const PianoDetector({super.key});

  @override
  State<PianoDetector> createState() => _PianoDetectorState();
}

class _PianoDetectorState extends State<PianoDetector> {
  final _audioRecorder = AudioRecorder();
  late PitchDetector _pitchDetector;
  StreamSubscription? _audioStreamSubscription;

  String _currentNote = "--";
  String _currentHz = "0.00 Hz";
  bool _isRecording = false;

  // Smoothing Variables
  final List<double> _pitchHistory = [];
  DateTime _lastUpdate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // ใช้ Buffer 2048 เพื่อความสมดุลระหว่างความเร็วและความแม่นยำ
    _pitchDetector = PitchDetector(audioSampleRate: 44100, bufferSize: 2048);
    _checkPermissionAndStart();
  }

  Future<void> _checkPermissionAndStart() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      _startDetection();
    } else {
      setState(() => _currentNote = "Permission Denied");
    }
  }

  Future<void> _startDetection() async {
    try {
      if (await _audioRecorder.isRecording()) await _audioRecorder.stop();

      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 44100,
        numChannels: 1,
      );

      final stream = await _audioRecorder.startStream(config);
      setState(() => _isRecording = true);

      _audioStreamSubscription = stream.listen((data) async {
        final buffer = _convertBytesToFloat(Uint8List.fromList(data));

        if (buffer.length >= 2048) {
          // ตรวจสอบความดัง (RMS) เพื่อตัด Noise
          double rms = sqrt(buffer.map((x) => x * x).reduce((a, b) => a + b) / buffer.length);
          
          if (rms > 0.01) { // ถ้าเสียงดังพอ
            final result = await _pitchDetector.getPitchFromFloatBuffer(buffer);
            if (result.pitched && result.probability > 0.85) {
              _updateNote(result.pitch);
            }
          } else {
            // ถ้าเงียบ ให้เคลียร์ค่า Hz
            if (mounted && DateTime.now().difference(_lastUpdate).inMilliseconds > 500) {
              setState(() {
                _currentHz = "Silence";
                _currentNote = "--";
              });
            }
          }
        }
      });
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _updateNote(double pitch) {
    if (pitch < 27 || pitch > 4200) return; // ช่วงเปียโน A0 - C8

    _pitchHistory.add(pitch);
    if (_pitchHistory.length > 5) _pitchHistory.removeAt(0);

    if (DateTime.now().difference(_lastUpdate).inMilliseconds > 150) {
      double avgPitch = _pitchHistory.reduce((a, b) => a + b) / _pitchHistory.length;
      setState(() {
        _currentHz = "${avgPitch.toStringAsFixed(2)} Hz";
        _currentNote = _getNoteFromHz(avgPitch);
      });
      _lastUpdate = DateTime.now();
    }
  }

  String _getNoteFromHz(double frequency) {
    int n = (12 * (log(frequency / 440) / log(2)) + 69).round();
    List<String> notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
    return "${notes[n % 12]}${(n ~/ 12) - 1}";
  }

  List<double> _convertBytesToFloat(Uint8List bytes) {
    final values = Int16List.view(bytes.buffer);
    return values.map((x) => x / 32768.0).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_currentHz, style: const TextStyle(color: Colors.greenAccent, fontSize: 24)),
            const SizedBox(height: 40),
            Text(_currentNote, style: const TextStyle(color: Colors.white, fontSize: 100, fontWeight: FontWeight.bold)),
            const SizedBox(height: 60),
            Icon(Icons.mic, color: _isRecording ? Colors.redAccent : Colors.grey, size: 40),
            const SizedBox(height: 10),
            Text(_isRecording ? "LISTENING" : "OFF", style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _audioStreamSubscription?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }
}
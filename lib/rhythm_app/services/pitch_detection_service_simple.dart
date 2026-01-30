import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';

/// Simple Pitch Detection Service - ใช้วิธีจาก main branch ที่แม่นที่สุด
class PitchDetectionServiceSimple {
  AudioRecorder? _audioRecorder;
  late PitchDetector _pitchDetector;
  StreamSubscription? _audioStreamSubscription;
  bool _isRecording = false;

  // Smoothing Variables
  final List<double> _pitchHistory = [];
  DateTime _lastUpdate = DateTime.now();

  // Callback เมื่อตรวจจับโน้ต
  Function(String note, double frequency, double confidence)? onNoteDetected;

  bool get isRecording => _isRecording;

  PitchDetectionServiceSimple() {
    // ใช้ Buffer 2048 เพื่อความสมดุลระหว่างความเร็วและความแม่นยำ
    _pitchDetector = PitchDetector(audioSampleRate: 44100, bufferSize: 2048);
  }

  Future<bool> start() async {
    print('🎙️ [SIMPLE] Starting pitch detection...');

    if (_isRecording) {
      print('⚠️ [SIMPLE] Already recording');
      return true;
    }

    try {
      // สร้าง AudioRecorder ใหม่ทุกครั้ง เพื่อหลีกเลี่ยงปัญหา state
      print('🔧 [SIMPLE] Creating new AudioRecorder...');
      _audioRecorder = AudioRecorder();

      print('🔐 [SIMPLE] Checking permission...');
      final hasPermission = await _audioRecorder!.hasPermission();
      print('🔐 [SIMPLE] Permission: $hasPermission');

      if (!hasPermission) {
        print('❌ [SIMPLE] No microphone permission');
        return false;
      }

      if (await _audioRecorder!.isRecording()) {
        await _audioRecorder!.stop();
      }

      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 44100,
        numChannels: 1,
      );

      print('🎤 [SIMPLE] Starting audio stream...');
      final stream = await _audioRecorder!.startStream(config);
      _isRecording = true;
      print('✅ [SIMPLE] Audio stream started!');

      // รอ 500ms และทิ้ง audio data แรก ๆ เพื่อให้ระบบ stabilize
      bool skipInitialFrames = true;
      DateTime startTime = DateTime.now();

      _audioStreamSubscription = stream.listen((data) async {
        if (skipInitialFrames) {
          if (DateTime.now().difference(startTime).inMilliseconds > 500) {
            skipInitialFrames = false;
            print('✅ [SIMPLE] Initial frames skipped, now processing...');
          } else {
            return; // ทิ้ง frame แรก ๆ
          }
        }
        await _processAudioData(Uint8List.fromList(data));
      });

      return true;
    } catch (e) {
      print('❌ [SIMPLE] Error: $e');
      return false;
    }
  }

  Future<void> _processAudioData(Uint8List data) async {
    final buffer = _convertBytesToFloat(data);

    if (buffer.length >= 2048) {
      // ตรวจสอบความดัง (RMS) เพื่อตัด Noise
      double rms = sqrt(
          buffer.map((x) => x * x).reduce((a, b) => a + b) / buffer.length);

      print('📊 [SIMPLE] RMS: ${rms.toStringAsFixed(4)}');

      if (rms > 0.01) {
        // ถ้าเสียงดังพอ
        final result = await _pitchDetector.getPitchFromFloatBuffer(buffer);
        print(
            '🎵 [SIMPLE] Pitched: ${result.pitched}, Freq: ${result.pitch.toStringAsFixed(1)}Hz, Prob: ${result.probability.toStringAsFixed(2)}');

        if (result.pitched && result.probability > 0.85) {
          _updateNote(result.pitch, result.probability);
        }
      } else {
        // ถ้าเงียบ ให้เคลียร์ history
        if (DateTime.now().difference(_lastUpdate).inMilliseconds > 500) {
          _pitchHistory.clear();
          print('🔇 [SIMPLE] Silence detected, clearing history');
        }
      }
    }
  }

  void _updateNote(double pitch, double probability) {
    if (pitch < 27 || pitch > 4200) {
      print('⚠️ [SIMPLE] Out of piano range: ${pitch.toStringAsFixed(1)}Hz');
      return; // ช่วงเปียโน A0 - C8
    }

    _pitchHistory.add(pitch);
    if (_pitchHistory.length > 5) _pitchHistory.removeAt(0);

    // Update ทุก 150ms
    if (DateTime.now().difference(_lastUpdate).inMilliseconds > 150) {
      double avgPitch =
          _pitchHistory.reduce((a, b) => a + b) / _pitchHistory.length;
      String note = _getNoteFromHz(avgPitch);

      print(
          '✅ [SIMPLE] Note detected: $note (${avgPitch.toStringAsFixed(1)}Hz)');

      onNoteDetected?.call(note, avgPitch, probability);
      _lastUpdate = DateTime.now();
    }
  }

  String _getNoteFromHz(double frequency) {
    int n = (12 * (log(frequency / 440) / log(2)) + 69).round();
    List<String> notes = [
      "C",
      "C#",
      "D",
      "D#",
      "E",
      "F",
      "F#",
      "G",
      "G#",
      "A",
      "A#",
      "B"
    ];
    return "${notes[n % 12]}${(n ~/ 12) - 1}";
  }

  List<double> _convertBytesToFloat(Uint8List bytes) {
    final values = Int16List.view(bytes.buffer);
    return values.map((x) => x / 32768.0).toList();
  }

  Future<void> stop() async {
    print('🛑 [SIMPLE] Stopping pitch detection...');

    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;
    print('✅ [SIMPLE] Stream cancelled');

    if (_audioRecorder != null && await _audioRecorder!.isRecording()) {
      print('🛑 [SIMPLE] Stopping recorder...');
      await _audioRecorder!.stop();
      print('✅ [SIMPLE] Recorder stopped');
    }

    // Dispose AudioRecorder เพื่อปล่อย resource
    if (_audioRecorder != null) {
      print('🗑️ [SIMPLE] Disposing recorder...');
      await _audioRecorder!.dispose();
      _audioRecorder = null;
      print('✅ [SIMPLE] Recorder disposed');
    }

    _isRecording = false;
    _pitchHistory.clear();
    print('🛑 [SIMPLE] Stopped completely');
  }

  Future<void> dispose() async {
    await stop();
    print('🗑️ [SIMPLE] Service disposed');
  }
}

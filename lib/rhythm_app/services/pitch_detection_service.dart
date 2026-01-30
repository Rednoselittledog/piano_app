import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:record/record.dart';

class PitchDetectionService {
  late final AudioRecorder _audioRecorder;
  late final PitchDetector _pitchDetector;
  bool _initialized = false;

  StreamSubscription? _audioStreamSubscription;
  bool _isRecording = false;

  // Note Onset Detection
  double _previousAmplitude = 0.0;
  double _previousPitch = 0.0;
  DateTime? _lastNoteTime;
  static const double _onsetThreshold = 3.0; // Amplitude ต้องเพิ่มขึ้น 3 เท่า
  static const int _minNoteIntervalMs = 100; // ห่างกันอย่างน้อย 100ms

  // Buffer accumulation
  final List<double> _audioBuffer = [];
  static const int _requiredBufferSize = 2048;

  void _ensureInitialized() {
    if (_initialized) return;
    _audioRecorder = AudioRecorder();
    _pitchDetector = PitchDetector(
      audioSampleRate: 16000,  // ต้องตรงกับ RecordConfig
      bufferSize: 2048, // ลดตาม sample rate (16000/44100 * 4096 ≈ 1489, ปัดเป็น 2048)
    );
    _initialized = true;
  }

  // Callback เมื่อตรวจจับโน้ต
  Function(String note, double frequency, double probability)? onNoteDetected;

  bool get isRecording => _isRecording;

  Future<bool> start() async {
    print('🎙️ [PITCH] Starting pitch detection...');

    if (_isRecording) {
      print('⚠️ [PITCH] Already recording');
      return true;
    }

    _ensureInitialized();
    print('✅ [PITCH] Initialized');

    try {
      print('🔐 [PITCH] Checking permission...');
      final hasPermission = await _audioRecorder.hasPermission();
      print('🔐 [PITCH] Permission: $hasPermission');

      if (!hasPermission) {
        print('❌ [PITCH] No microphone permission');
        return false;
      }

      // TEST #5: ลอง sample rate ต่ำกว่า
      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,  // ลดจาก 44100 เป็น 16000
        numChannels: 1,
        autoGain: false,  // ปิด auto gain
        echoCancel: false,  // ปิด echo cancellation
        noiseSuppress: false,  // ปิด noise suppression
      );

      print('🎤 [PITCH] Starting audio stream...');
      final stream = await _audioRecorder.startStream(config);
      _isRecording = true;
      print('✅ [PITCH] Audio stream started!');

      _audioStreamSubscription = stream.listen(
        (data) async {
          print('📦 [PITCH] Received audio data: ${data.length} bytes');
          await _processAudioData(data);
        },
        onError: (error) {
          print('❌ [PITCH] Audio stream error: $error');
        },
        onDone: () {
          print('⚠️ [PITCH] Audio stream done');
        },
        cancelOnError: false,
      );

      return true;
    } catch (e) {
      print('❌ [PITCH] Error starting pitch detection: $e');
      return false;
    }
  }

  Future<void> _processAudioData(Uint8List data) async {
    final buffer = _convertBytesToFloat(data);

    // สะสม buffer
    _audioBuffer.addAll(buffer);
    print('🔢 [PITCH] Buffer accumulated: ${_audioBuffer.length}/$_requiredBufferSize');

    // เมื่อครบ 4096 samples
    if (_audioBuffer.length >= _requiredBufferSize) {
      // ใช้เฉพาะ 4096 samples แรก
      final pitchBuffer = _audioBuffer.sublist(0, _requiredBufferSize);

      // ลบ samples ที่ใช้ไปแล้ว (overlap 50%)
      _audioBuffer.removeRange(0, _requiredBufferSize ~/ 2);

      // ===== TEST #7: แสดง raw audio data =====
      final minVal = pitchBuffer.reduce((a, b) => a < b ? a : b);
      final maxVal = pitchBuffer.reduce((a, b) => a > b ? a : b);
      final avgVal = pitchBuffer.reduce((a, b) => a + b) / pitchBuffer.length;

      // Check for zero crossings (บอก periodicity)
      int zeroCrossings = 0;
      for (int i = 1; i < pitchBuffer.length; i++) {
        if ((pitchBuffer[i-1] < 0 && pitchBuffer[i] >= 0) ||
            (pitchBuffer[i-1] >= 0 && pitchBuffer[i] < 0)) {
          zeroCrossings++;
        }
      }
      // ถ้า zero crossings มาก = noise, ถ้าน้อย = periodic signal
      final estimatedFreq = (zeroCrossings / 2.0) * (16000 / pitchBuffer.length);

      print('📊 [RAW] Min: ${minVal.toStringAsFixed(4)}, Max: ${maxVal.toStringAsFixed(4)}, Avg: ${avgVal.toStringAsFixed(4)}, Range: ${(maxVal - minVal).toStringAsFixed(4)}, ZC: $zeroCrossings (~${estimatedFreq.toStringAsFixed(0)}Hz)');

      // คำนวณ RMS amplitude ของ buffer
      final currentAmplitude = _calculateRMS(pitchBuffer);
      print('📈 [PITCH] RMS amplitude: ${currentAmplitude.toStringAsFixed(6)}');

      final result = await _pitchDetector.getPitchFromFloatBuffer(pitchBuffer);
      print('🎵 [PITCH] Pitched: ${result.pitched}, freq: ${result.pitch.toStringAsFixed(1)}Hz, prob: ${result.probability.toStringAsFixed(2)}');

      if (result.pitched) {
        // Debug: แสดงทุกเสียงที่ตรวจจับได้
        print('🎤 [PITCH] Detected: ${result.pitch.toStringAsFixed(1)}Hz, prob: ${result.probability.toStringAsFixed(2)}, amp: ${currentAmplitude.toStringAsFixed(4)}');

        // ===== TEST #6: ปิด onset detection, ปิด filters ยกเว้น low freq =====
        // กรองเฉพาะเสียงต่ำมาก ๆ < 100Hz
        if (result.pitch < 100) {
          print('⚠️ [PITCH] Filtered very low frequency noise (${result.pitch.toStringAsFixed(1)}Hz)');
          _previousAmplitude = currentAmplitude;
          _previousPitch = result.pitch;
          return;
        }

        // ส่งทุกเสียงที่ detect ได้ โดยไม่ต้องรอ onset
        var pitch = result.pitch;

        // Octave correction
        if (pitch < 65) {
          print('🔄 [PITCH] Octave correction: ${pitch.toStringAsFixed(1)}Hz -> ${(pitch * 2).toStringAsFixed(1)}Hz');
          pitch *= 2;
        }

        final note = _frequencyToNote(pitch);
        print('✅ [DETECT] Note sent! $note (${pitch.toStringAsFixed(1)}Hz)');

        onNoteDetected?.call(note, pitch, result.probability);

        _previousAmplitude = currentAmplitude;
        _previousPitch = result.pitch;
      } else {
        // ไม่มี pitched sound → reset amplitude
        _previousAmplitude = currentAmplitude;
      }
    } else {
      print('⏳ [PITCH] Waiting for more data...');
    }
  }

  // คำนวณ RMS (Root Mean Square) amplitude
  double _calculateRMS(List<double> buffer) {
    double sum = 0.0;
    for (final sample in buffer) {
      sum += sample * sample;
    }
    return sqrt(sum / buffer.length);
  }

  List<double> _convertBytesToFloat(Uint8List bytes) {
    final values = Int16List.view(bytes.buffer);
    return values.map((x) => x / 32768.0).toList();
  }

  String _frequencyToNote(double frequency) {
    int n = (12 * (log(frequency / 440) / log(2)) + 69).round();
    List<String> notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
    return "${notes[n % 12]}${(n ~/ 12) - 1}";
  }

  Future<void> stop() async {
    if (!_initialized) return;

    await _audioStreamSubscription?.cancel();
    _audioStreamSubscription = null;

    if (await _audioRecorder.isRecording()) {
      await _audioRecorder.stop();
    }

    _isRecording = false;
  }

  Future<void> dispose() async {
    if (!_initialized) return;

    await stop();
    await _audioRecorder.dispose();
  }
}

void debugPrint(String message) {
  print('[PitchDetection] $message');
}

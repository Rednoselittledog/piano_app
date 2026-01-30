import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:fftea/fftea.dart';

/// Pitch Detection Service ใช้ FFT algorithm
/// เหมาะกับ piano notes มากกว่า YIN
class PitchDetectionServiceFFT {
  late final AudioRecorder _audioRecorder;
  bool _initialized = false;

  StreamSubscription? _audioStreamSubscription;
  bool _isRecording = false;

  // Buffer accumulation
  final List<double> _audioBuffer = [];
  static const int _sampleRate = 44100;
  static const int _bufferSize = 4096;  // FFT ต้องการ power of 2

  // Callback เมื่อตรวจจับโน้ต
  Function(String note, double frequency, double confidence)? onNoteDetected;

  bool get isRecording => _isRecording;

  void _ensureInitialized() {
    if (_initialized) return;
    _audioRecorder = AudioRecorder();
    _initialized = true;
  }

  Future<bool> start() async {
    print('🎙️ [FFT] Starting pitch detection...');

    if (_isRecording) {
      print('⚠️ [FFT] Already recording');
      return true;
    }

    _ensureInitialized();
    print('✅ [FFT] Initialized');

    try {
      print('🔐 [FFT] Checking permission...');
      final hasPermission = await _audioRecorder.hasPermission();
      print('🔐 [FFT] Permission: $hasPermission');

      if (!hasPermission) {
        print('❌ [FFT] No microphone permission');
        return false;
      }

      const config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: _sampleRate,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      );

      print('🎤 [FFT] Starting audio stream...');
      final stream = await _audioRecorder.startStream(config);
      _isRecording = true;
      print('✅ [FFT] Audio stream started!');

      _audioStreamSubscription = stream.listen(
        (data) async {
          await _processAudioData(data);
        },
        onError: (error) {
          print('❌ [FFT] Audio stream error: $error');
        },
        onDone: () {
          print('⚠️ [FFT] Audio stream done');
        },
        cancelOnError: false,
      );

      return true;
    } catch (e) {
      print('❌ [FFT] Error starting pitch detection: $e');
      return false;
    }
  }

  Future<void> _processAudioData(Uint8List data) async {
    final buffer = _convertBytesToFloat(data);
    _audioBuffer.addAll(buffer);

    // เมื่อมี data พอสำหรับ FFT
    if (_audioBuffer.length >= _bufferSize) {
      final audioChunk = _audioBuffer.sublist(0, _bufferSize);
      _audioBuffer.removeRange(0, _bufferSize ~/ 2); // overlap 50%

      final result = _detectPitchFFT(audioChunk);

      if (result != null) {
        final note = _frequencyToNote(result.frequency);
        print('✅ [FFT] Detected: $note (${result.frequency.toStringAsFixed(1)}Hz, confidence: ${result.confidence.toStringAsFixed(2)})');
        onNoteDetected?.call(note, result.frequency, result.confidence);
      }
    }
  }

  /// ตรวจจับ pitch ด้วย FFT + HPS (Harmonic Product Spectrum)
  PitchResult? _detectPitchFFT(List<double> samples) {
    // คำนวณ RMS (volume)
    final rms = _calculateRMS(samples);

    // ถ้าเสียงเบาเกินไป ไม่ต้องประมวลผล
    if (rms < 0.02) {
      print('🔇 [FFT] Signal too weak (RMS: ${rms.toStringAsFixed(4)})');
      return null;
    }

    // Apply Hamming window เพื่อลด spectral leakage
    final windowed = _applyHammingWindow(samples);

    // FFT
    final fft = FFT(_bufferSize);
    final freq = fft.realFft(windowed);

    // คำนวณ magnitude spectrum
    final magnitudes = <double>[];
    for (int i = 0; i < freq.length; i++) {
      final real = freq[i].x;
      final imag = freq[i].y;
      final magnitude = sqrt(real * real + imag * imag);
      magnitudes.add(magnitude);
    }

    // HPS: Harmonic Product Spectrum เพื่อหา fundamental frequency
    // สำหรับ piano ที่มี harmonics ชัดเจน
    final hps = _harmonicProductSpectrum(magnitudes, 5); // ใช้ 5 harmonics

    // หา peak ในช่วง 200Hz - 600Hz (C3-E5, piano middle range)
    final minBin = (200 * _bufferSize / _sampleRate).floor();
    final maxBin = (600 * _bufferSize / _sampleRate).ceil();

    double maxHPS = 0;
    int maxBinIndex = minBin;

    for (int i = minBin; i < maxBin && i < hps.length; i++) {
      if (hps[i] > maxHPS) {
        maxHPS = hps[i];
        maxBinIndex = i;
      }
    }

    // แปลง bin index เป็น frequency
    final frequency = maxBinIndex * _sampleRate / _bufferSize;

    // คำนวณ confidence จาก HPS peak prominence และ RMS
    double avgHPS = 0;
    int countedBins = 0;
    for (int i = minBin; i < maxBin && i < hps.length; i++) {
      avgHPS += hps[i];
      countedBins++;
    }
    avgHPS /= countedBins;

    final peakProminence = maxHPS / (avgHPS + 0.0001);

    // ใช้ RMS เป็น factor เพิ่มเติม
    final rmsConfidence = (rms * 10).clamp(0.0, 1.0);
    final prominenceConfidence = (peakProminence / 50.0).clamp(0.0, 1.0);
    final confidence = (rmsConfidence * 0.3 + prominenceConfidence * 0.7);

    print('📊 [FFT+HPS] RMS: ${rms.toStringAsFixed(4)}, Freq: ${frequency.toStringAsFixed(1)}Hz, HPS: ${maxHPS.toStringAsFixed(2)}, Prom: ${peakProminence.toStringAsFixed(2)}, Conf: ${confidence.toStringAsFixed(2)}');

    // เข้มงวดมาก: confidence ต้องสูงกว่า 0.7 และ prominence ต้องสูงกว่า 20
    if (confidence < 0.7 || peakProminence < 20 || frequency < 200 || frequency > 600) {
      print('⚠️ [FFT] Rejected: conf=${confidence.toStringAsFixed(2)} prom=${peakProminence.toStringAsFixed(2)}');
      return null;
    }

    return PitchResult(frequency, confidence, rms);
  }

  /// HPS: Harmonic Product Spectrum
  /// คูณ spectrum ที่ downsample หลาย ๆ ระดับเพื่อหา fundamental frequency
  List<double> _harmonicProductSpectrum(List<double> magnitudes, int numHarmonics) {
    final length = magnitudes.length;
    final hps = List<double>.from(magnitudes);

    for (int h = 2; h <= numHarmonics; h++) {
      for (int i = 0; i < length ~/ h; i++) {
        hps[i] *= magnitudes[i * h];
      }
    }

    return hps;
  }

  /// Apply Hamming window
  List<double> _applyHammingWindow(List<double> samples) {
    final windowed = <double>[];
    final n = samples.length;
    for (int i = 0; i < n; i++) {
      final window = 0.54 - 0.46 * cos(2 * pi * i / (n - 1));
      windowed.add(samples[i] * window);
    }
    return windowed;
  }

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
    _audioBuffer.clear();
  }

  Future<void> dispose() async {
    if (!_initialized) return;

    await stop();
    await _audioRecorder.dispose();
  }
}

class PitchResult {
  final double frequency;
  final double confidence;
  final double rms;

  PitchResult(this.frequency, this.confidence, this.rms);
}

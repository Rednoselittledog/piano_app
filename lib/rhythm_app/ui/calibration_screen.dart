import 'package:flutter/material.dart';
import '../models/sample_songs.dart';
import '../services/metronome_service.dart';
import '../services/delay_calibration_service.dart';
import '../services/pitch_detection_service_simple.dart';
import '../widgets/colored_sheet_music.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key});

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  late final MetronomeService _metronome;
  late final DelayCalibrationService _calibration;
  late final PitchDetectionServiceSimple _pitchDetection;

  bool _isCalibrating = false;
  String _currentNote = '--';
  int? _delayOffset;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    // Initialize services
    _metronome = MetronomeService(bpm: 60);
    _calibration = DelayCalibrationService();
    _pitchDetection = PitchDetectionServiceSimple();

    // Defer ALL initialization to after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupCallbacks();

      _loadExistingCalibration().then((_) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });
    });
  }

  Future<void> _loadExistingCalibration() async {
    final offset = await _calibration.getDelayOffset();
    if (mounted && offset > 0) {
      setState(() => _delayOffset = offset);
    }
  }

  void _setupCallbacks() {
    _metronome.onBeat = (beatNumber) {
      _calibration.onMetronomeBeat(beatNumber);
    };

    _calibration.onProgress = (current, total) {
      if (mounted) {
        setState(() {});
      }
    };

    _calibration.onCalibrationComplete = (offset) {
      if (mounted) {
        setState(() {
          _delayOffset = offset;
          _isCalibrating = false;
        });
        _stopCalibration();
        _showCompletionDialog(offset);
      }
    };

    // Onset Detection callback - ใช้สำหรับ calibration (แม่นยำกว่า)
    _pitchDetection.onNoteOnset = (note, freq, onsetTime) {
      if (_isCalibrating && mounted) {
        setState(() => _currentNote = note);
        _calibration.onNoteDetected(note);
      }
    };

    // Pitch Detection callback - fallback
    _pitchDetection.onNoteDetected = (note, freq, prob) {
      if (_isCalibrating && mounted) {
        setState(() => _currentNote = note);
        // ใช้ onset เป็นหลัก ถ้าไม่มี onset ถึงใช้ตัวนี้
      }
    };
  }

  void _startCalibration() async {
    // เริ่ม pitch detection
    final started = await _pitchDetection.start();
    if (!started) {
      _showError('Cannot access microphone');
      return;
    }

    setState(() {
      _isCalibrating = true;
      _currentNote = '--';
    });

    _calibration.reset();
    _metronome.start();
  }

  void _stopCalibration() {
    _metronome.stop();
    _pitchDetection.stop();
    setState(() => _isCalibrating = false);
  }

  void _showCompletionDialog(int offset) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Calibration Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 20),
            Text(
              'Your delay: ${offset}ms',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Average delays: ${_calibration.delays.join(", ")}ms',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // ปิด dialog
              Navigator.pop(context); // กลับไปหน้า Home
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _metronome.dispose();
    _pitchDetection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calibrate Delay'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
        children: [
          // Sheet Music Display (ซ้าย)
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(10),
              child: Center(
                child: ColoredSheetMusic(
                  song: SampleSongs.calibrationSong,
                  noteColors: const {},
                  width: MediaQuery.of(context).size.width * 0.5,
                  height: 200,
                ),
              ),
            ),
          ),

          // Status Display (ขวา)
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  children: [
                  if (!_isCalibrating && _delayOffset != null) ...[
                    const Icon(Icons.check_circle, color: Colors.green, size: 50),
                    const SizedBox(height: 8),
                    Text(
                      'Calibrated: ${_delayOffset}ms',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'You can recalibrate anytime',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ] else if (!_isCalibrating) ...[
                    const Icon(Icons.info_outline, size: 50, color: Colors.blue),
                    const SizedBox(height: 10),
                    const Text(
                      'Calibration measures your detection delay',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Play C4 note 8 times with metronome',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    const Text(
                      '⚠️ ใช้หูฟังเพื่อฟัง metronome!',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'กดโน้ต C4 (Middle C) ตามจังหวะ!',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'C4 = 261Hz (คีย์กลาง piano)',
                      style: TextStyle(fontSize: 12, color: Colors.orange),
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: _calibration.progress.clamp(0.0, 1.0),
                      minHeight: 10,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${_calibration.beatCount} / ${_calibration.totalBeats}',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      'Detected: $_currentNote',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _currentNote == 'C4' ? Colors.green : Colors.red,
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Control Buttons
                  if (!_isCalibrating)
                    ElevatedButton.icon(
                      onPressed: _startCalibration,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Calibration'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _stopCalibration,
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                ],
              ),
            ),
            ),
          ),
        ],
      ),
    );
  }
}

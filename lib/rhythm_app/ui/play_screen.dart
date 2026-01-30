import 'package:flutter/material.dart';
import '../models/sample_songs.dart';
import '../models/song.dart';
import '../services/metronome_service.dart';
import '../services/pitch_detection_service_simple.dart';
import '../services/rhythm_judge_service.dart';
import '../services/delay_calibration_service.dart';
import '../widgets/colored_sheet_music.dart';
import 'result_screen.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  late final MetronomeService _metronome;
  late final PitchDetectionServiceSimple _pitchDetection;
  late final DelayCalibrationService _calibration;

  RhythmJudgeService? _judge;
  Song? _selectedSong;
  bool _isPlaying = false;
  bool _metronomeEnabled = true;
  String _currentNote = '--';
  Map<int, Color> _noteColors = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _selectedSong = SampleSongs.verySimpleTest;

    // Initialize services
    _metronome = MetronomeService(bpm: 120);
    _pitchDetection = PitchDetectionServiceSimple();
    _calibration = DelayCalibrationService();

    // Defer ALL initialization to after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupPitchDetection();

      _loadDelayAndInitJudge().then((_) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      });
    });
  }

  Future<void> _loadDelayAndInitJudge() async {
    final delay = await _calibration.getDelayOffset();
    _judge = RhythmJudgeService(
      song: _selectedSong!,
      delayOffset: delay,
    );
    _judge!.onJudgment = (judgment) {
      if (mounted) {
        setState(() {
          _noteColors[judgment.noteIndex] = judgment.color;
        });

        // เช็คว่าเล่นจบหรือยัง
        if (_judge!.isComplete) {
          _finishSong();
        }
      }
    };
  }

  void _setupPitchDetection() {
    _pitchDetection.onNoteDetected = (note, freq, prob) {
      if (mounted) {
        setState(() => _currentNote = note);
      }
      if (_isPlaying && _judge != null) {
        _judge!.onNoteDetected(note, DateTime.now());
      }
    };
  }

  void _startSong() async {
    // เริ่ม pitch detection
    final started = await _pitchDetection.start();
    if (!started) {
      _showError('Cannot access microphone');
      return;
    }

    setState(() {
      _isPlaying = true;
      _noteColors = {};
      _currentNote = '--';
    });

    // รีเซ็ต judge
    _judge?.reset();

    // เริ่ม metronome
    if (_metronomeEnabled) {
      _metronome.start();
    }
  }

  void _stopSong() {
    _metronome.stop();
    _pitchDetection.stop();
    setState(() => _isPlaying = false);
  }

  void _finishSong() {
    _stopSong();

    // แสดงผลลัพธ์
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          song: _selectedSong!,
          judge: _judge!,
        ),
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
        title: const Text('Practice'),
        actions: [
          // เลือกเพลง
          PopupMenuButton<Song>(
            icon: const Icon(Icons.library_music),
            onSelected: (song) {
              setState(() {
                _selectedSong = song;
                _loadDelayAndInitJudge();
              });
            },
            itemBuilder: (context) => SampleSongs.allSongs.map((song) {
              return PopupMenuItem(
                value: song,
                child: Text(song.title),
              );
            }).toList(),
          ),
        ],
      ),
      body: Row(
        children: [
          // Sheet Music Display (ซ้าย)
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(10),
              child: Center(
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : (_selectedSong != null
                        ? ColoredSheetMusic(
                            song: _selectedSong!,
                            noteColors: _noteColors,
                            width: MediaQuery.of(context).size.width * 0.5,
                            height: 200,
                          )
                        : const CircularProgressIndicator()),
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
                  Text(
                    _selectedSong?.title ?? '',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'BPM: ${_selectedSong?.bpm ?? 120}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 15),
                  if (_isPlaying) ...[
                    Text(
                      'Detected: $_currentNote',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Progress: ${_judge?.currentNoteIndex ?? 0} / ${_selectedSong?.notes.length ?? 0}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (_judge?.currentNoteIndex ?? 0) / (_selectedSong?.notes.length ?? 1),
                      minHeight: 6,
                    ),
                  ] else ...[
                    const Icon(Icons.play_circle_outline, size: 60, color: Colors.blue),
                    const SizedBox(height: 10),
                    const Text(
                      'Ready to play!',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],

                  // Legend (ถ้ากำลังเล่น)
                  if (_isPlaying) ...[
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildLegendItem(Colors.green, 'Perfect'),
                        const SizedBox(width: 10),
                        _buildLegendItem(Colors.yellow, 'Good'),
                        const SizedBox(width: 10),
                        _buildLegendItem(Colors.red, 'Miss'),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    const SizedBox(height: 20),
                  ],

                  // Control Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                // Metronome Toggle
                IconButton(
                  onPressed: () {
                    setState(() => _metronomeEnabled = !_metronomeEnabled);
                    if (_isPlaying) {
                      if (_metronomeEnabled) {
                        _metronome.start();
                      } else {
                        _metronome.stop();
                      }
                    }
                  },
                  icon: Icon(
                    _metronomeEnabled ? Icons.volume_up : Icons.volume_off,
                  ),
                  iconSize: 32,
                ),
                const SizedBox(width: 30),

                // Play/Stop Button
                if (!_isPlaying)
                  ElevatedButton.icon(
                    onPressed: _startSong,
                    icon: const Icon(Icons.play_arrow, size: 32),
                    label: const Text('Start'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      textStyle: const TextStyle(fontSize: 20),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _stopSong,
                    icon: const Icon(Icons.stop, size: 32),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      textStyle: const TextStyle(fontSize: 20),
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                    ],
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

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(label),
      ],
    );
  }
}

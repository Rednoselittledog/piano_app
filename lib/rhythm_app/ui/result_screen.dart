import 'package:flutter/material.dart';
import '../models/song.dart';
import '../services/rhythm_judge_service.dart';
import '../widgets/colored_sheet_music.dart';

class ResultScreen extends StatelessWidget {
  final Song song;
  final RhythmJudgeService judge;

  const ResultScreen({
    super.key,
    required this.song,
    required this.judge,
  });

  @override
  Widget build(BuildContext context) {
    final stats = judge.getStatistics();
    final accuracy = judge.getAccuracy();
    final noteColors = Map<int, Color>.from(
      judge.judgments.map((index, judgment) => MapEntry(index, judgment.color)),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Accuracy Score
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: accuracy >= 80
                        ? [Colors.green.shade400, Colors.green.shade600]
                        : accuracy >= 60
                            ? [Colors.yellow.shade400, Colors.yellow.shade600]
                            : [Colors.red.shade400, Colors.red.shade600],
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Accuracy',
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${accuracy.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        fontSize: 60,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Statistics
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Text(
                        'Statistics',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      _buildStatRow(
                        Icons.check_circle,
                        'Perfect',
                        stats['perfect']!,
                        Colors.green,
                      ),
                      const SizedBox(height: 10),
                      _buildStatRow(
                        Icons.check,
                        'Good',
                        stats['good']!,
                        Colors.yellow.shade700,
                      ),
                      const SizedBox(height: 10),
                      _buildStatRow(
                        Icons.close,
                        'Miss',
                        stats['miss']!,
                        Colors.red,
                      ),
                      const Divider(height: 30),
                      _buildStatRow(
                        Icons.music_note,
                        'Total Notes',
                        stats['total']!,
                        Colors.blue,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Sheet Music with Colors
              const Text(
                'Performance Review',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Container(
                height: 200,
                color: Colors.grey[100],
                child: Center(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ColoredSheetMusic(
                      song: song,
                      noteColors: noteColors,
                      width: 800,
                      height: 150,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem(Colors.green, 'Perfect'),
                  const SizedBox(width: 20),
                  _buildLegendItem(Colors.yellow, 'Good'),
                  const SizedBox(width: 20),
                  _buildLegendItem(Colors.red, 'Miss'),
                ],
              ),

              const SizedBox(height: 30),

              // Detailed Judgments (optional)
              if (judge.judgments.isNotEmpty) ...[
                const Text(
                  'Detailed Results',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                ...judge.judgments.entries.map((entry) {
                  final judgment = entry.value;
                  return Card(
                    color: judgment.color.withOpacity(0.1),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: judgment.color,
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        'Expected: ${judgment.expectedNote} | Played: ${judgment.playedNote}',
                      ),
                      subtitle: Text(
                        _getTimingMessage(judgment),
                      ),
                      trailing: Icon(
                        judgment.level == JudgmentLevel.perfect
                            ? Icons.check_circle
                            : judgment.level == JudgmentLevel.good
                                ? Icons.check
                                : Icons.close,
                        color: judgment.color,
                      ),
                    ),
                  );
                }),
              ],

              const SizedBox(height: 30),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // กลับไปหน้า Play
                    },
                    icon: const Icon(Icons.replay),
                    label: const Text('Play Again'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.popUntil(context, (route) => route.isFirst); // กลับไปหน้าแรก
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('Home'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, int value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
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

  String _getTimingMessage(Judgment judgment) {
    final timingDiff = judgment.actualTime - judgment.expectedTime;
    final timingMs = (timingDiff * 1000).round();

    if (timingMs > 0) {
      return 'กดช้า ${timingMs}ms (${judgment.errorPercent.toStringAsFixed(1)}%)';
    } else if (timingMs < 0) {
      return 'กดเร็ว ${(-timingMs)}ms (${judgment.errorPercent.toStringAsFixed(1)}%)';
    } else {
      return 'ตรงเวลาพอดี! (${judgment.errorPercent.toStringAsFixed(1)}%)';
    }
  }
}

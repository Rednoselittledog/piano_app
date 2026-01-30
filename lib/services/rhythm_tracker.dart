import 'dart:async';
import '../models/song_models.dart';

/// ระบบตรวจจับจังหวะและการเล่นโน้ต
class RhythmTracker {
  Song? currentSong;
  DateTime? songStartTime;
  int currentNoteIndex = 0;
  List<PlayResult> results = [];
  bool isPlaying = false;

  // Timing windows (กรอบเวลาที่ยอมรับได้) - ขยายให้กว้างมาก
  static const double perfectWindow = 0.15; // ±150ms
  static const double greatWindow = 0.3; // ±300ms
  static const double goodWindow = 0.5; // ±500ms
  static const double earlyWindow = 0.5; // สามารถกดก่อนได้ไม่เกิน 500ms (ลดจาก 800ms)

  // Callbacks สำหรับ update UI
  Function(double currentTime)? onTimeUpdate;
  Function(PlayResult result)? onNoteScored;
  Function(Map<String, dynamic> stats)? onStatsUpdate;

  Timer? _updateTimer;

  /// เริ่มเพลง
  void startSong(Song song) {
    currentSong = song;
    songStartTime = DateTime.now();
    currentNoteIndex = 0;
    results.clear();
    isPlaying = true;

    // Update timer ทุก 16ms (~60fps)
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (isPlaying) {
        final currentTime = getCurrentTime();
        onTimeUpdate?.call(currentTime);
        _checkMissedNotes();

        // จบเพลงอัตโนมัติ
        if (currentTime > song.totalDuration + 2.0) {
          stopSong();
        }
      }
    });
  }

  /// หยุดเพลง
  void stopSong() {
    isPlaying = false;
    _updateTimer?.cancel();
    _updateStats();
  }

  /// รีเซ็ต
  void reset() {
    stopSong();
    currentSong = null;
    songStartTime = null;
    currentNoteIndex = 0;
    results.clear();
  }

  /// เวลาปัจจุบันในเพลง (วินาที)
  double getCurrentTime() {
    if (songStartTime == null) return 0.0;
    return DateTime.now().difference(songStartTime!).inMilliseconds / 1000.0;
  }

  /// หาโน้ตที่ควรจะเล่นตอนนี้
  NoteEvent? getCurrentExpectedNote() {
    if (currentSong == null || !isPlaying) return null;
    if (currentNoteIndex >= currentSong!.notes.length) return null;

    final currentTime = getCurrentTime();
    final note = currentSong!.notes[currentNoteIndex];

    // ลดเวลาที่แสดงว่าเป็น "current" ให้น้อยลง
    // กดก่อนได้ไม่เกิน 0.3 วินาที (แทน earlyWindow)
    final timeDiff = currentTime - note.startTime;
    if (timeDiff >= -0.3 && timeDiff <= note.duration + goodWindow) {
      return note;
    }

    return null;
  }

  /// หาโน้ตถัดไป (สำหรับแสดง preview)
  List<NoteEvent> getUpcomingNotes({int count = 10}) {
    if (currentSong == null) return [];

    final currentTime = getCurrentTime();
    final upcoming = <NoteEvent>[];

    for (int i = currentNoteIndex; i < currentSong!.notes.length && upcoming.length < count; i++) {
      final note = currentSong!.notes[i];
      if (note.startTime >= currentTime - 0.5) {
        upcoming.add(note);
      }
    }

    return upcoming;
  }

  /// เมื่อตรวจจับโน้ตได้
  void onNoteDetected(String detectedNote) {
    if (!isPlaying || currentSong == null) {
      print("DEBUG: Not playing or no song");
      return;
    }

    final expected = getCurrentExpectedNote();
    if (expected == null) {
      print("DEBUG: No expected note at this time");
      return;
    }

    final currentTime = getCurrentTime();
    final timingError = currentTime - expected.startTime;

    // ตรวจสอบว่าโน้ตตรงกันหรือไม่
    final noteMatches = _checkNoteMatch(detectedNote, expected);

    print("DEBUG: Detected=$detectedNote, Expected=${expected.note}, Match=$noteMatches, TimingError=${timingError.toStringAsFixed(3)}s");

    if (noteMatches) {
      final grade = _calculateGrade(timingError.abs());

      final result = PlayResult(
        expectedNote: expected.note,
        playedNote: detectedNote,
        timingError: timingError,
        isCorrect: true,
        grade: grade,
        timestamp: DateTime.now(),
      );

      results.add(result);
      onNoteScored?.call(result);
      currentNoteIndex++;
      _updateStats();
      print("DEBUG: ✓ Note scored: ${grade.name.toUpperCase()}");
    }
  }

  /// ตรวจสอบว่าโน้ตที่พลาดไปแล้ว
  void _checkMissedNotes() {
    if (currentSong == null || !isPlaying) return;

    final currentTime = getCurrentTime();

    while (currentNoteIndex < currentSong!.notes.length) {
      final note = currentSong!.notes[currentNoteIndex];
      final missTime = note.startTime + note.duration + goodWindow;

      if (currentTime > missTime) {
        // โน้ตนี้พลาดแล้ว
        _recordMiss(note);
        currentNoteIndex++;
      } else {
        break;
      }
    }
  }

  /// บันทึกโน้ตที่พลาด
  void _recordMiss(NoteEvent note) {
    final result = PlayResult(
      expectedNote: note.note,
      playedNote: null,
      timingError: double.infinity,
      isCorrect: false,
      grade: ScoreGrade.miss,
      timestamp: DateTime.now(),
    );

    results.add(result);
    onNoteScored?.call(result);
    _updateStats();
  }

  /// ตรวจสอบว่าโน้ตตรงกันหรือไม่
  /// ยอมรับโน้ตข้างเคียง ±2 semitones
  bool _checkNoteMatch(String played, NoteEvent expected) {
    if (expected.isChord && expected.chordNotes != null) {
      return expected.chordNotes!.contains(played);
    }

    // แปลงโน้ตเป็นตัวเลข semitone
    final expectedSemitone = _noteToSemitone(expected.note);
    final playedSemitone = _noteToSemitone(played);

    // ยอมรับโน้ตที่ห่างกัน ±2 semitones
    final difference = (playedSemitone - expectedSemitone).abs();
    return difference <= 2; // C ยอมรับ A#, B, C, C#, D
  }

  /// แปลงโน้ตเป็น semitone number (C0 = 0)
  int _noteToSemitone(String note) {
    final noteNames = {
      'C': 0, 'C#': 1, 'D': 2, 'D#': 3, 'E': 4, 'F': 5,
      'F#': 6, 'G': 7, 'G#': 8, 'A': 9, 'A#': 10, 'B': 11,
      'Db': 1, 'Eb': 3, 'Gb': 6, 'Ab': 8, 'Bb': 10,
    };

    // แยกชื่อโน้ตและ octave
    final match = RegExp(r'([A-G][#b]?)(\d+)').firstMatch(note);
    if (match == null) return 0;

    final noteName = match.group(1)!;
    final octave = int.parse(match.group(2)!);

    final semitoneInOctave = noteNames[noteName] ?? 0;
    return octave * 12 + semitoneInOctave;
  }

  /// คำนวณเกรด
  ScoreGrade _calculateGrade(double absError) {
    if (absError <= perfectWindow) return ScoreGrade.perfect;
    if (absError <= greatWindow) return ScoreGrade.great;
    if (absError <= goodWindow) return ScoreGrade.good;
    return ScoreGrade.miss;
  }

  /// คำนวณสถิติ
  void _updateStats() {
    if (results.isEmpty) {
      onStatsUpdate?.call({
        'perfect': 0,
        'great': 0,
        'good': 0,
        'miss': 0,
        'accuracy': 0.0,
        'score': 0,
      });
      return;
    }

    final perfect = results.where((r) => r.grade == ScoreGrade.perfect).length;
    final great = results.where((r) => r.grade == ScoreGrade.great).length;
    final good = results.where((r) => r.grade == ScoreGrade.good).length;
    final miss = results.where((r) => r.grade == ScoreGrade.miss).length;

    final accuracy = (results.where((r) => r.isCorrect).length / results.length * 100);
    final score = perfect * 100 + great * 70 + good * 40;

    onStatsUpdate?.call({
      'perfect': perfect,
      'great': great,
      'good': good,
      'miss': miss,
      'accuracy': accuracy,
      'score': score,
    });
  }

  /// ดึงสถิติปัจจุบัน
  Map<String, dynamic> getStats() {
    if (results.isEmpty) {
      return {
        'perfect': 0,
        'great': 0,
        'good': 0,
        'miss': 0,
        'accuracy': 0.0,
        'score': 0,
      };
    }

    final perfect = results.where((r) => r.grade == ScoreGrade.perfect).length;
    final great = results.where((r) => r.grade == ScoreGrade.great).length;
    final good = results.where((r) => r.grade == ScoreGrade.good).length;
    final miss = results.where((r) => r.grade == ScoreGrade.miss).length;

    final accuracy = (results.where((r) => r.isCorrect).length / results.length * 100);
    final score = perfect * 100 + great * 70 + good * 40;

    return {
      'perfect': perfect,
      'great': great,
      'good': good,
      'miss': miss,
      'accuracy': accuracy,
      'score': score,
    };
  }

  void dispose() {
    _updateTimer?.cancel();
  }
}

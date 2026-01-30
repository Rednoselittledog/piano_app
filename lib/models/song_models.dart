// โครงสร้างข้อมูลสำหรับเพลง - ออกแบบให้ง่ายต่อการ import/export ในอนาคต

/// โน้ตแต่ละตัวในเพลง
class NoteEvent {
  final String note; // เช่น "C4", "D4", "E4"
  final double startTime; // วินาทีที่ต้องเริ่มกด (นับจาก 0)
  final double duration; // ความยาวของโน้ต (วินาที)
  final bool isChord; // เป็นคอร์ดหรือไม่
  final List<String>? chordNotes; // ถ้าเป็นคอร์ด ให้ระบุโน้ตทั้งหมด

  NoteEvent({
    required this.note,
    required this.startTime,
    required this.duration,
    this.isChord = false,
    this.chordNotes,
  });

  // สำหรับ import/export JSON ในอนาคต
  Map<String, dynamic> toJson() => {
        'note': note,
        'startTime': startTime,
        'duration': duration,
        'isChord': isChord,
        'chordNotes': chordNotes,
      };

  factory NoteEvent.fromJson(Map<String, dynamic> json) => NoteEvent(
        note: json['note'],
        startTime: json['startTime'],
        duration: json['duration'],
        isChord: json['isChord'] ?? false,
        chordNotes: json['chordNotes'] != null
            ? List<String>.from(json['chordNotes'])
            : null,
      );

  // หาตำแหน่งบนบันไดห้าเส้น (staff position)
  // C4 = 0, D4 = 1, E4 = 2, F4 = 3, G4 = 4, A4 = 5, B4 = 6, C5 = 7...
  int getStaffPosition() {
    final noteNames = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
    String noteName = note.replaceAll(RegExp(r'[#b0-9]'), '');
    int octave = int.parse(note.replaceAll(RegExp(r'[^0-9]'), ''));

    int basePosition = noteNames.indexOf(noteName);
    return (octave - 4) * 7 + basePosition;
  }
}

/// เพลง
class Song {
  final String id; // ID สำหรับระบุเพลง
  final String title; // ชื่อเพลง
  final int bpm; // Beats Per Minute
  final List<NoteEvent> notes; // โน้ตทั้งหมดในเพลง
  final String? artist; // ผู้แต่ง (optional)
  final String? difficulty; // ระดับความยาก (optional)

  Song({
    required this.id,
    required this.title,
    required this.bpm,
    required this.notes,
    this.artist,
    this.difficulty,
  });

  double get beatDuration => 60.0 / bpm; // วินาทีต่อ beat
  double get totalDuration {
    if (notes.isEmpty) return 0.0;
    final lastNote = notes.last;
    return lastNote.startTime + lastNote.duration;
  }

  // สำหรับ import/export JSON ในอนาคต
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'bpm': bpm,
        'notes': notes.map((n) => n.toJson()).toList(),
        'artist': artist,
        'difficulty': difficulty,
      };

  factory Song.fromJson(Map<String, dynamic> json) => Song(
        id: json['id'],
        title: json['title'],
        bpm: json['bpm'],
        notes: (json['notes'] as List)
            .map((n) => NoteEvent.fromJson(n))
            .toList(),
        artist: json['artist'],
        difficulty: json['difficulty'],
      );
}

/// ผลการให้คะแนนแต่ละโน้ต
enum ScoreGrade {
  perfect, // ±30ms
  great, // ±60ms
  good, // ±100ms
  miss, // พลาดหรือนอกกรอบเวลา
}

/// ผลการเล่นแต่ละโน้ต
class PlayResult {
  final String expectedNote;
  final String? playedNote;
  final double timingError; // ความผิดพลาดของเวลา (วินาที) - เช่น -0.05 = เร็วไป 50ms
  final bool isCorrect;
  final ScoreGrade grade;
  final DateTime timestamp;

  PlayResult({
    required this.expectedNote,
    this.playedNote,
    required this.timingError,
    required this.isCorrect,
    required this.grade,
    required this.timestamp,
  });

  String get gradeText {
    switch (grade) {
      case ScoreGrade.perfect:
        return 'PERFECT';
      case ScoreGrade.great:
        return 'GREAT';
      case ScoreGrade.good:
        return 'GOOD';
      case ScoreGrade.miss:
        return 'MISS';
    }
  }

  String get timingText {
    if (timingError.isInfinite) return '--';
    final ms = (timingError * 1000).round();
    if (ms > 0) return '+${ms}ms';
    if (ms < 0) return '${ms}ms';
    return 'Perfect!';
  }
}

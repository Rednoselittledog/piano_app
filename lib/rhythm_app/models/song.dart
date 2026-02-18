class Song {
  final String id;
  final String title;
  final int bpm;
  final String timeSignature; 
  final List<NoteEvent> notes;

  Song({
    required this.id,
    required this.title,
    required this.bpm,
    this.timeSignature = "4/4",
    required this.notes,
  });

  // คำนวณจำนวนห้องทั้งหมด
  int get totalMeasures {
    if (notes.isEmpty) return 0;
    final lastNote = notes.last;
    final totalBeats = (lastNote.startTime + lastNote.duration) * (bpm / 60);
    final beatsPerMeasure = int.parse(timeSignature.split('/')[0]);
    return (totalBeats / beatsPerMeasure).ceil();
  }

  // แปลง recording เป็น Song
  factory Song.fromRecording(List<RecordedNote> recordedNotes, int bpm) {
    final notes = recordedNotes.map((rn) => NoteEvent(
      note: rn.note,
      startTime: rn.timestamp,
      duration: 0.5, // ใช้ quarter note เป็น default
    )).toList();

    return Song(
      id: 'recording_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Recorded Performance',
      bpm: bpm,
      notes: notes,
    );
  }
}

class NoteEvent {
  final String note; // "C4", "D4", etc.
  final double startTime; // วินาที
  final double duration; // วินาที (0.25 = sixteenth, 0.5 = eighth, 1.0 = quarter)

  NoteEvent({
    required this.note,
    required this.startTime,
    required this.duration,
  });

  // แปลง duration เป็น NoteDuration enum สำหรับ simple_sheet_music
  String get noteDurationType {
    if (duration <= 0.25) return 'sixteenth';
    if (duration <= 0.5) return 'eighth';
    if (duration <= 1.0) return 'quarter';
    if (duration <= 2.0) return 'half';
    return 'whole';
  }

  NoteEvent copyWith({String? note, double? startTime, double? duration}) {
    return NoteEvent(
      note: note ?? this.note,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
    );
  }

  Map<String, dynamic> toJson() => {
    'note': note,
    'startTime': startTime,
    'duration': duration,
  };

  factory NoteEvent.fromJson(Map<String, dynamic> json) => NoteEvent(
    note: json['note'],
    startTime: json['startTime'],
    duration: json['duration'],
  );
}

class RecordedNote {
  final String note;
  final double timestamp; // วินาทีนับจากเริ่มเพลง

  RecordedNote({
    required this.note,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'note': note,
    'timestamp': timestamp,
  };

  factory RecordedNote.fromJson(Map<String, dynamic> json) => RecordedNote(
    note: json['note'],
    timestamp: json['timestamp'],
  );
}

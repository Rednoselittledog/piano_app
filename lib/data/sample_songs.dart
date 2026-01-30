import '../models/song_models.dart';

/// เพลงตัวอย่างสำหรับทดสอบ
/// ในอนาคตสามารถโหลดจาก JSON file หรือ API ได้
class SampleSongs {
  /// Twinkle Twinkle Little Star - เพลงง่ายสำหรับเริ่มต้น
  /// เพิ่มเวลาเตรียมตัว 3 วินาที ก่อนโน้ตแรก
  static Song get twinkleTwinkle => Song(
        id: 'twinkle_twinkle',
        title: 'Twinkle Twinkle Little Star',
        bpm: 120,
        artist: 'Traditional',
        difficulty: 'Easy',
        notes: [
          // "Twin-kle twin-kle lit-tle star"
          NoteEvent(note: 'C4', startTime: 3.0, duration: 0.5), // เริ่มที่ 3 วินาที
          NoteEvent(note: 'C4', startTime: 3.5, duration: 0.5),
          NoteEvent(note: 'G4', startTime: 4.0, duration: 0.5),
          NoteEvent(note: 'G4', startTime: 4.5, duration: 0.5),
          NoteEvent(note: 'A4', startTime: 5.0, duration: 0.5),
          NoteEvent(note: 'A4', startTime: 5.5, duration: 0.5),
          NoteEvent(note: 'G4', startTime: 6.0, duration: 1.0),

          // "How I won-der what you are"
          NoteEvent(note: 'F4', startTime: 7.0, duration: 0.5),
          NoteEvent(note: 'F4', startTime: 7.5, duration: 0.5),
          NoteEvent(note: 'E4', startTime: 8.0, duration: 0.5),
          NoteEvent(note: 'E4', startTime: 8.5, duration: 0.5),
          NoteEvent(note: 'D4', startTime: 9.0, duration: 0.5),
          NoteEvent(note: 'D4', startTime: 9.5, duration: 0.5),
          NoteEvent(note: 'C4', startTime: 10.0, duration: 1.0),

          // "Up a-bove the world so high"
          NoteEvent(note: 'G4', startTime: 11.0, duration: 0.5),
          NoteEvent(note: 'G4', startTime: 11.5, duration: 0.5),
          NoteEvent(note: 'F4', startTime: 12.0, duration: 0.5),
          NoteEvent(note: 'F4', startTime: 12.5, duration: 0.5),
          NoteEvent(note: 'E4', startTime: 13.0, duration: 0.5),
          NoteEvent(note: 'E4', startTime: 13.5, duration: 0.5),
          NoteEvent(note: 'D4', startTime: 14.0, duration: 1.0),

          // "Like a dia-mond in the sky"
          NoteEvent(note: 'G4', startTime: 15.0, duration: 0.5),
          NoteEvent(note: 'G4', startTime: 15.5, duration: 0.5),
          NoteEvent(note: 'F4', startTime: 16.0, duration: 0.5),
          NoteEvent(note: 'F4', startTime: 16.5, duration: 0.5),
          NoteEvent(note: 'E4', startTime: 17.0, duration: 0.5),
          NoteEvent(note: 'E4', startTime: 17.5, duration: 0.5),
          NoteEvent(note: 'D4', startTime: 18.0, duration: 1.0),

          // "Twin-kle twin-kle lit-tle star" (repeat)
          NoteEvent(note: 'C4', startTime: 19.0, duration: 0.5),
          NoteEvent(note: 'C4', startTime: 19.5, duration: 0.5),
          NoteEvent(note: 'G4', startTime: 20.0, duration: 0.5),
          NoteEvent(note: 'G4', startTime: 20.5, duration: 0.5),
          NoteEvent(note: 'A4', startTime: 21.0, duration: 0.5),
          NoteEvent(note: 'A4', startTime: 21.5, duration: 0.5),
          NoteEvent(note: 'G4', startTime: 22.0, duration: 1.0),

          // "How I won-der what you are" (repeat)
          NoteEvent(note: 'F4', startTime: 23.0, duration: 0.5),
          NoteEvent(note: 'F4', startTime: 23.5, duration: 0.5),
          NoteEvent(note: 'E4', startTime: 24.0, duration: 0.5),
          NoteEvent(note: 'E4', startTime: 24.5, duration: 0.5),
          NoteEvent(note: 'D4', startTime: 25.0, duration: 0.5),
          NoteEvent(note: 'D4', startTime: 25.5, duration: 0.5),
          NoteEvent(note: 'C4', startTime: 26.0, duration: 1.5),
        ],
      );

  /// C Major Scale - สำหรับฝึกเบสิก
  /// เพิ่มเวลาเตรียมตัว 3 วินาที
  static Song get cMajorScale => Song(
        id: 'c_major_scale',
        title: 'C Major Scale',
        bpm: 100,
        difficulty: 'Beginner',
        notes: [
          NoteEvent(note: 'C4', startTime: 3.0, duration: 0.6),
          NoteEvent(note: 'D4', startTime: 3.6, duration: 0.6),
          NoteEvent(note: 'E4', startTime: 4.2, duration: 0.6),
          NoteEvent(note: 'F4', startTime: 4.8, duration: 0.6),
          NoteEvent(note: 'G4', startTime: 5.4, duration: 0.6),
          NoteEvent(note: 'A4', startTime: 6.0, duration: 0.6),
          NoteEvent(note: 'B4', startTime: 6.6, duration: 0.6),
          NoteEvent(note: 'C5', startTime: 7.2, duration: 1.2),
        ],
      );

  /// รายการเพลงทั้งหมด
  static List<Song> get allSongs => [
        twinkleTwinkle,
        cMajorScale,
      ];

  /// หาเพลงจาก ID
  static Song? getSongById(String id) {
    try {
      return allSongs.firstWhere((song) => song.id == id);
    } catch (e) {
      return null;
    }
  }
}

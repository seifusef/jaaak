/// Domain models for the IndoPak Mushaf viewer.
///
/// Every piece of Quranic text in these models is read verbatim from the
/// QUL (https://qul.tarteel.ai) IndoPak word-by-word SQLite database.
/// Nothing is ever generated or hard-coded in the app.
library;

/// Line types as stored in the QUL mushaf-layout `pages` table.
enum MushafLineType {
  surahName,
  ayah,
  basmallah,
  unknown;

  static MushafLineType fromDb(String? value) {
    switch (value) {
      case 'surah_name':
        return MushafLineType.surahName;
      case 'ayah':
        return MushafLineType.ayah;
      case 'basmallah':
        return MushafLineType.basmallah;
      default:
        return MushafLineType.unknown;
    }
  }
}

/// A single word from the QUL IndoPak script database.
class MushafWord {
  const MushafWord({
    required this.id,
    required this.surah,
    required this.ayah,
    required this.text,
  });

  final int id;
  final int surah;
  final int ayah;

  /// IndoPak Nastaleeq text, exactly as exported by QUL.
  final String text;
}

/// One line of a mushaf page, as described by the QUL layout database.
class MushafLine {
  const MushafLine({
    required this.lineNumber,
    required this.type,
    required this.isCentered,
    this.surahNumber,
    this.words = const [],
  });

  final int lineNumber;
  final MushafLineType type;
  final bool isCentered;

  /// Set for `surah_name` lines.
  final int? surahNumber;

  /// Words of this line for `ayah` / `basmallah` lines, in mushaf order.
  final List<MushafWord> words;

  /// The line text, joined exactly from the QUL words.
  String get text => words.map((w) => w.text).join(' ');
}

/// A full mushaf page (15 lines for the IndoPak layout).
class MushafPage {
  const MushafPage({required this.pageNumber, required this.lines});

  final int pageNumber;
  final List<MushafLine> lines;
}

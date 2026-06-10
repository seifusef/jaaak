import 'models.dart';

/// Read-only access to the IndoPak mushaf data (QUL "Indopak 15 lines"
/// layout + QUL IndoPak word-by-word script).
///
/// Implementations:
///  * [SqliteIndoPakMushafRepository] — native platforms, reads the two QUL
///    SQLite exports directly (sqflite).
///  * [JsonIndoPakMushafRepository] — web, reads a compact JSON asset that
///    `tool/convert_qul_to_json.py` generates from the same two QUL SQLite
///    files at build time (sqflite does not work on web).
///
/// Whatever the backend, every word ultimately originates from the
/// downloaded QUL databases — the app never generates Quranic text.
abstract class IndoPakMushafRepository {
  /// Number of pages in the layout (610 for the IndoPak 15-line mushaf).
  Future<int> getPageCount();

  /// Lines + words of a single page, in mushaf order.
  Future<MushafPage> getPage(int pageNumber);

  /// Surah display names if the QUL export provides them, empty otherwise.
  Future<Map<int, String>> getSurahNames();

  /// Releases any underlying resources (e.g. open database handles).
  Future<void> dispose();
}

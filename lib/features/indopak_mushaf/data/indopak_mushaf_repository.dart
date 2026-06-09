import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';

/// Read-only access to the two QUL SQLite exports:
///
///  * layout DB — `pages` table (line_number, line_type, is_centered,
///    first_word_id, last_word_id, surah_number) from the
///    "Indopak 15 lines" mushaf layout;
///  * words DB — `words` table (word id, text, surah, ayah) from the
///    IndoPak word-by-word script.
///
/// Column names differ slightly between QUL export versions (e.g. `word_id`
/// vs `word_index`), so they are resolved once via `PRAGMA table_info`
/// instead of being hard-coded. No Quranic text is ever produced here —
/// every word comes straight out of the QUL words database.
class IndoPakMushafRepository {
  IndoPakMushafRepository._({
    required Database layoutDb,
    required Database wordsDb,
    required _PagesSchema pagesSchema,
    required _WordsSchema wordsSchema,
  })  : _layoutDb = layoutDb,
        _wordsDb = wordsDb,
        _pages = pagesSchema,
        _words = wordsSchema;

  static Future<IndoPakMushafRepository> open({
    required Database layoutDb,
    required Database wordsDb,
  }) async {
    final pagesSchema = await _PagesSchema.resolve(layoutDb);
    final wordsSchema = await _WordsSchema.resolve(wordsDb);
    return IndoPakMushafRepository._(
      layoutDb: layoutDb,
      wordsDb: wordsDb,
      pagesSchema: pagesSchema,
      wordsSchema: wordsSchema,
    );
  }

  final Database _layoutDb;
  final Database _wordsDb;
  final _PagesSchema _pages;
  final _WordsSchema _words;

  List<MushafWord>? _basmallahCache;
  Map<int, String>? _surahNamesCache;

  /// Number of pages in the layout (610 for the IndoPak 15-line mushaf).
  Future<int> getPageCount() async {
    final rows = await _layoutDb
        .rawQuery('SELECT MAX(${_pages.page}) AS max_page FROM pages');
    final count = rows.first['max_page'];
    if (count is int && count > 0) return count;
    throw StateError('QUL layout database has no pages.');
  }

  Future<MushafPage> getPage(int pageNumber) async {
    final rows = await _layoutDb.query(
      'pages',
      where: '${_pages.page} = ?',
      whereArgs: [pageNumber],
      orderBy: _pages.lineNumber,
    );

    final lines = <MushafLine>[];
    for (final row in rows) {
      final type = MushafLineType.fromDb(row[_pages.lineType] as String?);
      final firstWordId = _asInt(row[_pages.firstWordId]);
      final lastWordId = _asInt(row[_pages.lastWordId]);

      List<MushafWord> words = const [];
      if (firstWordId != null && lastWordId != null) {
        words = await _wordRange(firstWordId, lastWordId);
      } else if (type == MushafLineType.basmallah) {
        // Basmallah lines without word ids reuse the basmallah words from
        // the QUL words database (surah 1, ayah 1).
        words = await _basmallahWords();
      }

      lines.add(MushafLine(
        lineNumber: _asInt(row[_pages.lineNumber]) ?? lines.length + 1,
        type: type,
        isCentered: _asInt(row[_pages.isCentered]) == 1,
        surahNumber: _asInt(row[_pages.surahNumber]),
        words: words,
      ));
    }

    if (lines.isEmpty) {
      throw StateError('No layout data for page $pageNumber in QUL export.');
    }
    return MushafPage(pageNumber: pageNumber, lines: lines);
  }

  Future<List<MushafWord>> _wordRange(int firstId, int lastId) async {
    final rows = await _wordsDb.query(
      'words',
      where: '${_words.id} BETWEEN ? AND ?',
      whereArgs: [firstId, lastId],
      orderBy: _words.id,
    );
    return rows.map(_toWord).toList(growable: false);
  }

  Future<List<MushafWord>> _basmallahWords() async {
    if (_basmallahCache != null) return _basmallahCache!;
    // Al-Fatiha 1:1 is the basmallah in the IndoPak script export. The
    // trailing ayah-number marker word (if present) is dropped.
    final rows = await _wordsDb.query(
      'words',
      where: '${_words.surah} = 1 AND ${_words.ayah} = 1',
      orderBy: _words.id,
    );
    if (rows.isEmpty) {
      throw StateError('QUL words database is missing surah 1 ayah 1.');
    }
    var words = rows.map(_toWord).toList(growable: false);
    if (words.length > 4) words = words.sublist(0, 4);
    return _basmallahCache = words;
  }

  /// Surah display names, only if the QUL export ships a metadata table
  /// (`chapters` or `surahs`) with an Arabic name column. Returns an empty
  /// map otherwise — the UI then falls back to the surah number. Names are
  /// never hard-coded in the app.
  Future<Map<int, String>> getSurahNames() async {
    if (_surahNamesCache != null) return _surahNamesCache!;
    for (final db in [_layoutDb, _wordsDb]) {
      for (final table in ['chapters', 'surahs']) {
        final columns = await _tableColumns(db, table);
        if (columns.isEmpty) continue;
        final idCol = _firstOf(columns, ['id', 'surah_number', 'chapter_id']);
        final nameCol = _firstOf(
            columns, ['name_arabic', 'arabic_name', 'name_ar', 'name']);
        if (idCol == null || nameCol == null) continue;
        final rows = await db.query(table, columns: [idCol, nameCol]);
        final names = <int, String>{
          for (final row in rows)
            if (_asInt(row[idCol]) != null && row[nameCol] is String)
              _asInt(row[idCol])!: row[nameCol] as String,
        };
        if (names.isNotEmpty) return _surahNamesCache = names;
      }
    }
    return _surahNamesCache = const {};
  }

  MushafWord _toWord(Map<String, Object?> row) {
    final text = row[_words.text];
    if (text is! String || text.isEmpty) {
      // Per project policy we never substitute missing Quran text.
      throw StateError(
          'QUL words database returned an empty word (id ${row[_words.id]}).');
    }
    return MushafWord(
      id: _asInt(row[_words.id]) ?? 0,
      surah: _asInt(row[_words.surah]) ?? 0,
      ayah: _asInt(row[_words.ayah]) ?? 0,
      text: text,
    );
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

Future<Set<String>> _tableColumns(Database db, String table) async {
  try {
    final rows = await db.rawQuery('PRAGMA table_info($table)');
    return rows.map((r) => r['name'] as String).toSet();
  } catch (_) {
    return const {};
  }
}

String? _firstOf(Set<String> columns, List<String> candidates) {
  for (final candidate in candidates) {
    if (columns.contains(candidate)) return candidate;
  }
  return null;
}

/// Column names of the layout `pages` table, resolved per export version.
class _PagesSchema {
  const _PagesSchema({
    required this.page,
    required this.lineNumber,
    required this.lineType,
    required this.isCentered,
    required this.firstWordId,
    required this.lastWordId,
    required this.surahNumber,
  });

  final String page;
  final String lineNumber;
  final String lineType;
  final String isCentered;
  final String firstWordId;
  final String lastWordId;
  final String surahNumber;

  static Future<_PagesSchema> resolve(Database layoutDb) async {
    final columns = await _tableColumns(layoutDb, 'pages');
    if (columns.isEmpty) {
      throw StateError(
          'QUL layout database has no `pages` table — wrong file? '
          'Re-run tool/fetch_qul_assets.sh.');
    }
    String pick(List<String> candidates) {
      final col = _firstOf(columns, candidates);
      if (col == null) {
        throw StateError(
            'QUL layout `pages` table is missing a ${candidates.first} '
            'column (found: $columns).');
      }
      return col;
    }

    return _PagesSchema(
      page: pick(['page_number', 'page']),
      lineNumber: pick(['line_number', 'line']),
      lineType: pick(['line_type', 'type']),
      isCentered: pick(['is_centered', 'centered']),
      firstWordId: pick(['first_word_id']),
      lastWordId: pick(['last_word_id']),
      surahNumber: pick(['surah_number', 'surah', 'chapter']),
    );
  }
}

/// Column names of the script `words` table, resolved per export version.
class _WordsSchema {
  const _WordsSchema({
    required this.id,
    required this.text,
    required this.surah,
    required this.ayah,
  });

  final String id;
  final String text;
  final String surah;
  final String ayah;

  static Future<_WordsSchema> resolve(Database wordsDb) async {
    final columns = await _tableColumns(wordsDb, 'words');
    if (columns.isEmpty) {
      throw StateError(
          'QUL words database has no `words` table — wrong file? '
          'Re-run tool/fetch_qul_assets.sh.');
    }
    String pick(List<String> candidates) {
      final col = _firstOf(columns, candidates);
      if (col == null) {
        throw StateError(
            'QUL `words` table is missing a ${candidates.first} column '
            '(found: $columns).');
      }
      return col;
    }

    return _WordsSchema(
      id: pick(['word_id', 'word_index', 'id']),
      text: pick(['text', 'word_text', 'word']),
      surah: pick(['surah', 'surah_number', 'chapter']),
      ayah: pick(['ayah', 'ayah_number', 'verse']),
    );
  }
}

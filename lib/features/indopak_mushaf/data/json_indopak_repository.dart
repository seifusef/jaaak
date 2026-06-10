import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../domain/indopak_repository.dart';
import '../domain/models.dart';
import 'indopak_assets.dart';

/// Web implementation of [IndoPakMushafRepository].
///
/// Reads `assets/indopak/mushaf_data.json`, which is generated at build time
/// by `tool/convert_qul_to_json.py` from the two downloaded QUL SQLite
/// exports (layout + IndoPak word-by-word script). The JSON is a pure
/// transformation of the QUL data — no text is ever added or altered, and
/// missing data raises an error instead of being substituted.
class JsonIndoPakMushafRepository implements IndoPakMushafRepository {
  @visibleForTesting
  JsonIndoPakMushafRepository.fromData(Map<String, Object?> data)
      : _data = data {
    final pages = _data['pages'];
    if (pages is! List || pages.isEmpty) {
      throw StateError(
          'QUL JSON asset contains no pages — regenerate it with '
          'tool/convert_qul_to_json.py from the QUL SQLite exports.');
    }
    _pages = pages;
  }

  static Future<JsonIndoPakMushafRepository> load() async {
    final String raw;
    try {
      raw = await rootBundle.loadString(IndoPakAssets.mushafJson);
    } catch (_) {
      throw const IndoPakAssetsMissingException(IndoPakAssets.mushafJson);
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw StateError('QUL JSON asset is malformed (not an object).');
    }
    return JsonIndoPakMushafRepository.fromData(
        decoded.cast<String, Object?>());
  }

  final Map<String, Object?> _data;
  late final List<dynamic> _pages;
  final Map<int, MushafPage> _pageCache = {};

  @override
  Future<int> getPageCount() async => _pages.length;

  @override
  Future<MushafPage> getPage(int pageNumber) async {
    if (pageNumber < 1 || pageNumber > _pages.length) {
      throw RangeError.range(pageNumber, 1, _pages.length, 'pageNumber');
    }
    return _pageCache[pageNumber] ??= _parsePage(pageNumber);
  }

  @override
  Future<Map<int, String>> getSurahNames() async {
    final raw = _data['surah_names'];
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        if (int.tryParse('${entry.key}') != null && entry.value is String)
          int.parse('${entry.key}'): entry.value as String,
    };
  }

  @override
  Future<void> dispose() async {}

  MushafPage _parsePage(int pageNumber) {
    final raw = _pages[pageNumber - 1];
    if (raw is! List || raw.isEmpty) {
      throw StateError('QUL JSON asset has no lines for page $pageNumber.');
    }
    final lines = <MushafLine>[];
    for (final entry in raw) {
      final map = (entry as Map).cast<String, Object?>();
      final wordsRaw = map['w'];
      final words = <MushafWord>[];
      if (wordsRaw is List) {
        for (final word in wordsRaw) {
          if (word is! String || word.isEmpty) {
            // Per project policy we never substitute missing Quran text.
            throw StateError(
                'QUL JSON asset contains an empty word on page $pageNumber '
                '— regenerate it from the QUL SQLite exports.');
          }
          words.add(MushafWord(id: 0, surah: 0, ayah: 0, text: word));
        }
      }
      lines.add(MushafLine(
        lineNumber: (map['l'] as num?)?.toInt() ?? lines.length + 1,
        type: MushafLineType.fromDb(map['t'] as String?),
        isCentered: (map['c'] as num?)?.toInt() == 1,
        surahNumber: (map['s'] as num?)?.toInt(),
        words: words,
      ));
    }
    return MushafPage(pageNumber: pageNumber, lines: lines);
  }
}

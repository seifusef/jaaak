import 'package:arkani_indopak_prototype/features/indopak_mushaf/data/json_indopak_repository.dart';
import 'package:arkani_indopak_prototype/features/indopak_mushaf/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

// Test fixtures use latin placeholder strings only — never Quranic text.
Map<String, Object?> fixture() => {
      'version': 1,
      'page_count': 2,
      'surah_names': {'1': 'name-one'},
      'pages': [
        [
          {'l': 1, 't': 'surah_name', 'c': 1, 's': 1},
          {
            'l': 2,
            't': 'basmallah',
            'c': 1,
            'w': ['b1', 'b2'],
          },
          {
            'l': 3,
            't': 'ayah',
            'c': 0,
            'w': ['w1', 'w2', 'w3'],
          },
        ],
        [
          {
            'l': 1,
            't': 'ayah',
            'c': 1,
            'w': ['w4'],
          },
        ],
      ],
    };

void main() {
  test('reports page count from pages list', () async {
    final repo = JsonIndoPakMushafRepository.fromData(fixture());
    expect(await repo.getPageCount(), 2);
  });

  test('parses lines, types, centering and words in order', () async {
    final repo = JsonIndoPakMushafRepository.fromData(fixture());
    final page = await repo.getPage(1);

    expect(page.pageNumber, 1);
    expect(page.lines, hasLength(3));
    expect(page.lines[0].type, MushafLineType.surahName);
    expect(page.lines[0].surahNumber, 1);
    expect(page.lines[1].type, MushafLineType.basmallah);
    expect(page.lines[1].isCentered, isTrue);
    expect(page.lines[1].text, 'b1 b2');
    expect(page.lines[2].type, MushafLineType.ayah);
    expect(page.lines[2].isCentered, isFalse);
    expect(page.lines[2].text, 'w1 w2 w3');
  });

  test('exposes surah names with int keys', () async {
    final repo = JsonIndoPakMushafRepository.fromData(fixture());
    expect(await repo.getSurahNames(), {1: 'name-one'});
  });

  test('rejects out-of-range page numbers', () async {
    final repo = JsonIndoPakMushafRepository.fromData(fixture());
    expect(() => repo.getPage(0), throwsRangeError);
    expect(() => repo.getPage(3), throwsRangeError);
  });

  test('refuses empty words instead of substituting text', () {
    final data = fixture();
    ((data['pages'] as List)[1] as List)[0] = {
      'l': 1,
      't': 'ayah',
      'c': 0,
      'w': ['ok', ''],
    };
    final repo = JsonIndoPakMushafRepository.fromData(data);
    expect(() => repo.getPage(2), throwsStateError);
  });

  test('refuses data without pages', () {
    expect(
      () => JsonIndoPakMushafRepository.fromData({'pages': []}),
      throwsStateError,
    );
  });
}

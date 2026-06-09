import 'package:arkani_indopak_prototype/features/indopak_mushaf/domain/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MushafLineType.fromDb', () {
    test('maps QUL line_type values', () {
      expect(MushafLineType.fromDb('surah_name'), MushafLineType.surahName);
      expect(MushafLineType.fromDb('ayah'), MushafLineType.ayah);
      expect(MushafLineType.fromDb('basmallah'), MushafLineType.basmallah);
      expect(MushafLineType.fromDb('something'), MushafLineType.unknown);
      expect(MushafLineType.fromDb(null), MushafLineType.unknown);
    });
  });

  group('MushafLine', () {
    test('joins QUL words verbatim without altering text', () {
      const line = MushafLine(
        lineNumber: 2,
        type: MushafLineType.ayah,
        isCentered: false,
        words: [
          MushafWord(id: 1, surah: 1, ayah: 2, text: 'a'),
          MushafWord(id: 2, surah: 1, ayah: 2, text: 'b'),
        ],
      );
      expect(line.text, 'a b');
    });

    test('empty line renders no text', () {
      const line = MushafLine(
        lineNumber: 1,
        type: MushafLineType.surahName,
        isCentered: true,
      );
      expect(line.text, isEmpty);
    });
  });
}

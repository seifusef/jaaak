import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/indopak_database.dart';
import '../data/indopak_font.dart';
import '../data/indopak_mushaf_repository.dart';
import '../domain/models.dart';

/// Initializes the IndoPak Mushaf feature: loads the QUL Nastaleeq font and
/// opens the two QUL SQLite databases. Fails with
/// [IndoPakAssetsMissingException] when the assets have not been fetched.
final indoPakRepositoryProvider =
    FutureProvider<IndoPakMushafRepository>((ref) async {
  await loadIndoPakFont();
  const opener = IndoPakDatabaseOpener();
  final layoutDb = await opener.openLayoutDb();
  final wordsDb = await opener.openWordsDb();
  ref.onDispose(() {
    layoutDb.close();
    wordsDb.close();
  });
  return IndoPakMushafRepository.open(layoutDb: layoutDb, wordsDb: wordsDb);
});

/// Total page count as reported by the QUL layout database
/// (610 for the IndoPak 15-line mushaf).
final indoPakPageCountProvider = FutureProvider<int>((ref) async {
  final repo = await ref.watch(indoPakRepositoryProvider.future);
  return repo.getPageCount();
});

/// Lines + words of a single page, fetched from the QUL databases.
final indoPakPageProvider =
    FutureProvider.family<MushafPage, int>((ref, pageNumber) async {
  final repo = await ref.watch(indoPakRepositoryProvider.future);
  return repo.getPage(pageNumber);
});

/// Surah display names if the QUL export includes a metadata table;
/// empty map otherwise (UI falls back to surah numbers).
final indoPakSurahNamesProvider = FutureProvider<Map<int, String>>((ref) async {
  final repo = await ref.watch(indoPakRepositoryProvider.future);
  return repo.getSurahNames();
});

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/indopak_font.dart';
// Platform-conditional data source: QUL SQLite exports via sqflite on
// native, the build-time JSON conversion of the same QUL exports on web.
import '../data/repository_loader_io.dart'
    if (dart.library.js_interop) '../data/repository_loader_web.dart'
    as loader;
import '../domain/indopak_repository.dart';
import '../domain/models.dart';

/// Initializes the IndoPak Mushaf feature: loads the QUL Nastaleeq font and
/// opens the QUL data source for the current platform. Fails with
/// [IndoPakAssetsMissingException] when the assets have not been fetched.
final indoPakRepositoryProvider =
    FutureProvider<IndoPakMushafRepository>((ref) async {
  await loadIndoPakFont();
  final repository = await loader.loadIndoPakRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

/// Total page count as reported by the QUL layout database
/// (610 for the IndoPak 15-line mushaf).
final indoPakPageCountProvider = FutureProvider<int>((ref) async {
  final repo = await ref.watch(indoPakRepositoryProvider.future);
  return repo.getPageCount();
});

/// Lines + words of a single page, fetched from the QUL data.
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

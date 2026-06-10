import '../domain/indopak_repository.dart';
import 'indopak_database.dart';
import 'sqlite_indopak_repository.dart';

/// Native (Android/iOS/desktop) loader: opens the two bundled QUL SQLite
/// exports with sqflite. Selected via the conditional import in
/// `application/providers.dart`.
Future<IndoPakMushafRepository> loadIndoPakRepository() async {
  const opener = IndoPakDatabaseOpener();
  final layoutDb = await opener.openLayoutDb();
  final wordsDb = await opener.openWordsDb();
  return SqliteIndoPakMushafRepository.open(
    layoutDb: layoutDb,
    wordsDb: wordsDb,
  );
}

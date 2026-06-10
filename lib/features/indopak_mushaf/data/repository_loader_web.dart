import '../domain/indopak_repository.dart';
import 'json_indopak_repository.dart';

/// Web loader: sqflite is unavailable in the browser, so the web build reads
/// the JSON asset that `tool/convert_qul_to_json.py` generated from the same
/// two QUL SQLite exports at build time. Selected via the conditional import
/// in `application/providers.dart`.
Future<IndoPakMushafRepository> loadIndoPakRepository() =>
    JsonIndoPakMushafRepository.load();

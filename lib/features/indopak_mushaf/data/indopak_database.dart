import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'indopak_assets.dart';

/// Opens the two QUL SQLite databases bundled as assets.
///
/// SQLite cannot read directly from the Flutter asset bundle, so each
/// database is copied once into the application support directory and then
/// opened read-only. The copy is refreshed whenever the bundled asset size
/// changes (i.e. after updating the QUL export).
class IndoPakDatabaseOpener {
  const IndoPakDatabaseOpener();

  Future<Database> openLayoutDb() => _openFromAsset(IndoPakAssets.layoutDb);

  Future<Database> openWordsDb() => _openFromAsset(IndoPakAssets.wordsDb);

  Future<Database> _openFromAsset(String assetPath) async {
    final ByteData data;
    try {
      data = await rootBundle.load(assetPath);
    } catch (_) {
      throw IndoPakAssetsMissingException(assetPath);
    }

    final supportDir = await getApplicationSupportDirectory();
    final dbDir = Directory(p.join(supportDir.path, 'indopak_mushaf'));
    await dbDir.create(recursive: true);
    final file = File(p.join(dbDir.path, p.basename(assetPath)));

    final needsCopy =
        !await file.exists() || await file.length() != data.lengthInBytes;
    if (needsCopy) {
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }

    return openDatabase(file.path, readOnly: true);
  }
}

import 'package:flutter/services.dart';

import 'indopak_assets.dart';

/// Loads the QUL IndoPak Nastaleeq font at runtime.
///
/// The font is loaded with [FontLoader] instead of a pubspec `fonts:` entry
/// so the project still builds before `tool/fetch_qul_assets.sh` has been
/// run (the viewer then shows an instructive error screen instead).
Future<void> loadIndoPakFont() async {
  final ByteData data;
  try {
    data = await rootBundle.load(IndoPakAssets.font);
  } catch (_) {
    throw const IndoPakAssetsMissingException(IndoPakAssets.font);
  }
  final loader = FontLoader(IndoPakAssets.fontFamily)
    ..addFont(Future.value(data));
  await loader.load();
}

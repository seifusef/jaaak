import 'package:flutter/material.dart';

import '../../data/indopak_assets.dart';
import '../../domain/models.dart';

/// Renders one mushaf line as a single [Text] in the QUL IndoPak Nastaleeq
/// font. The line's word sequence comes straight from the QUL databases —
/// the widget never alters or supplements the text.
///
/// Each line is scaled with a [FittedBox] so that all 15 lines fit any
/// screen width without overflow while preserving the printed line breaks:
///  * centered lines (surah endings, basmallah) keep their natural width;
///  * regular ayah lines are stretched to the full line width, matching the
///    justified look of the printed mushaf.
class MushafLineWidget extends StatelessWidget {
  const MushafLineWidget({super.key, required this.line});

  final MushafLine line;

  static const _baseStyle = TextStyle(
    fontFamily: IndoPakAssets.fontFamily,
    fontSize: 28,
    color: Color(0xFF1F1B16),
    height: 1.0,
  );

  @override
  Widget build(BuildContext context) {
    final text = line.text;
    if (text.isEmpty) return const SizedBox.expand();

    return SizedBox.expand(
      child: FittedBox(
        fit: line.isCentered ? BoxFit.scaleDown : BoxFit.fitWidth,
        alignment: Alignment.center,
        child: Text(
          text,
          maxLines: 1,
          textDirection: TextDirection.rtl,
          style: _baseStyle,
        ),
      ),
    );
  }
}

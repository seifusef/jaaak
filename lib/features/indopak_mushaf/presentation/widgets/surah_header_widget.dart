import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';

/// Decorative surah header for `surah_name` layout lines.
///
/// The surah name is shown only when the QUL export provides it (via a
/// metadata table); otherwise the header falls back to the surah number in
/// Arabic-Indic digits. Surah names are never hard-coded in the app.
class SurahHeaderWidget extends ConsumerWidget {
  const SurahHeaderWidget({super.key, required this.surahNumber});

  final int? surahNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final names = ref.watch(indoPakSurahNamesProvider).value ?? const {};
    final name = surahNumber == null ? null : names[surahNumber];
    final label = name ?? 'سُورَة ${_arabicDigits(surahNumber)}';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF8D6E2F), width: 1.5),
        borderRadius: BorderRadius.circular(6),
        color: const Color(0xFFF6EFDD),
      ),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Text(
            label,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5C4516),
            ),
          ),
        ),
      ),
    );
  }

  static String _arabicDigits(int? value) {
    if (value == null) return '';
    const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var text = '$value';
    for (var i = 0; i < western.length; i++) {
      text = text.replaceAll(western[i], eastern[i]);
    }
    return text;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers.dart';
import '../../domain/models.dart';
import 'mushaf_line_widget.dart';
import 'surah_header_widget.dart';

/// A single IndoPak mushaf page: the lines reported by the QUL layout
/// database stacked in a [Column], each line getting an equal slot so the
/// full 15-line page always fits the screen.
class MushafPageWidget extends ConsumerWidget {
  const MushafPageWidget({super.key, required this.pageNumber});

  final int pageNumber;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final page = ref.watch(indoPakPageProvider(pageNumber));
    return page.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _PageError(pageNumber: pageNumber, error: error),
      data: (page) => _PageBody(page: page),
    );
  }
}

class _PageBody extends StatelessWidget {
  const _PageBody({required this.page});

  final MushafPage page;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFDF8EE),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                for (final line in page.lines)
                  Expanded(
                    child: line.type == MushafLineType.surahName
                        ? SurahHeaderWidget(surahNumber: line.surahNumber)
                        : MushafLineWidget(line: line),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${page.pageNumber}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.brown.shade400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageError extends StatelessWidget {
  const _PageError({required this.pageNumber, required this.error});

  final int pageNumber;
  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'تعذّر تحميل الصفحة $pageNumber\n$error',
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
        ),
      ),
    );
  }
}

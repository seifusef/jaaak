import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/feature_flags.dart';
import 'features/indopak_mushaf/presentation/indopak_mushaf_screen.dart';

// Prototype host app for the IndoPak Mushaf feature module.
//
// NOTE: this repository contained no application code, so this minimal shell
// stands in for the Arkani app. When merging into Arkani, only
// `lib/features/indopak_mushaf/`, `lib/core/feature_flags.dart`, the assets
// and the entry-point tile below need to be carried over — nothing here
// touches or replaces any existing Mushaf (Madinah/QCF) code.
void main() {
  runApp(const ProviderScope(child: ArkaniPrototypeApp()));
}

class ArkaniPrototypeApp extends StatelessWidget {
  const ArkaniPrototypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arkani — IndoPak Mushaf Prototype',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8D6E2F)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arkani')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Temporary entry point for the IndoPak Mushaf prototype.
          // Hidden entirely when kEnableIndoPakMushaf is false.
          if (kEnableIndoPakMushaf)
            Card(
              child: ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: const Text(
                  'مصحف إندوباك (تجريبي)',
                  textDirection: TextDirection.rtl,
                ),
                subtitle: const Text('IndoPak 15-line mushaf — QUL data'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const IndoPakMushafScreen(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

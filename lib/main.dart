// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'providers/settings_provider.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await StorageService.init();
  WakelockPlus.enable();
  runApp(const ProviderScope(child: ChordViewerApp()));
}

class ChordViewerApp extends ConsumerWidget {
  const ChordViewerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final locale = settings.locale != null ? Locale(settings.locale!) : null;

    return MaterialApp(
      title: 'Chord Viewer',
      debugShowCheckedModeBanner: false,
      locale: locale,
      supportedLocales: const [Locale('es'), Locale('en')],
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pethouse/app/providers.dart';
import 'package:pethouse/app/router.dart';
import 'package:pethouse/app/theme.dart';
import 'package:pethouse/objectbox.g.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await openStore();
  runApp(
    ProviderScope(
      overrides: [
        objectBoxStoreProvider.overrideWithValue(store),
      ],
      child: const PetHouseApp(),
    ),
  );
}

class PetHouseApp extends StatelessWidget {
  const PetHouseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PetHouse',
      theme: AppTheme.light(),
      routerConfig: appRouter,
    );
  }
}

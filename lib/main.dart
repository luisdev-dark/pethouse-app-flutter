import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pethouse/app/providers.dart';
import 'package:pethouse/app/router.dart';
import 'package:pethouse/app/theme.dart';
import 'package:pethouse/objectbox.g.dart';

import 'package:pethouse/shared/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = await openStore();
  final prefs = await SharedPreferences.getInstance();

  // Initialize notifications early
  final notifications = NotificationService();
  await notifications.initialize();

  runApp(
    ProviderScope(
      overrides: [
        objectBoxStoreProvider.overrideWithValue(store),
        sharedPreferencesProvider.overrideWithValue(prefs),
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

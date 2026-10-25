import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/chemistry.dart';
import 'core/store.dart';
import 'app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final store = StudioStore(
      await ChemistryData.load(),
      SharedPreferencesAsync(),
    );
    await store.restore();
    runApp(
      ProviderScope(
        overrides: [studioProvider.overrideWithValue(store)],
        child: const UniverseApp(),
      ),
    );
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text('Could not load offline chemistry data: $e'),
          ),
        ),
      ),
    );
  }
}

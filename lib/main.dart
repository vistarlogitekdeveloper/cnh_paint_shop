import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/db/app_database.dart';
import 'core/push/push_service.dart';
import 'core/storage/token_store.dart';
import 'providers/providers.dart';

/// Entry point.
///
/// The keystore read and the SQLite open both happen HERE, before the first
/// frame, and are injected as provider overrides. Doing them lazily inside a
/// provider would mean the router's first redirect could not know whether there
/// is a session — and an already-signed-in operator would see a login flash
/// before being bounced to their dashboard.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Edge-to-edge with transparent system bars, so the ambient background's
  // aurora runs behind the system chrome instead of being cut off by a grey band.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final tokens = await TokenStore.open();
  final database = AppDatabase();

  // Push is optional: without a Firebase config the app runs fine and only loses
  // notifications. A missing google-services.json must never stop the plant from
  // recording receipts.
  if (Env.enablePush) {
    await PushService.initialise();
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    if (kReleaseMode) debugPrint('[error] ${details.exceptionAsString()}');
  };

  runApp(
    ProviderScope(
      overrides: [
        tokenStoreProvider.overrideWithValue(tokens),
        appDatabaseProvider.overrideWithValue(database),
      ],
      child: const CnhPaintShopApp(),
    ),
  );
}

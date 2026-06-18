import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app.dart';
import 'state/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock to portrait by default — KYC + scanning flows expect it.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Dark status bar icons against our dark surfaces.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF08070C),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  final hasOnboardedStr = await storage.read(key: 'has_onboarded');
  final hasOnboarded = hasOnboardedStr == 'true';

  runApp(ProviderScope(
    overrides: [
      hasOnboardedProvider.overrideWith(() => HasOnboarded(hasOnboarded)),
    ],
    child: const WalletApp(),
  ));
}

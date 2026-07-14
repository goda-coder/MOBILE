import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app.dart';
import 'state/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _initApp();
}

Future<void> _initApp() async {
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color(0xFF08070C),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  final hasOnboardedStr = await storage.read(key: 'has_onboarded');
  final hasOnboarded = hasOnboardedStr == 'true';

  runApp(ProviderScope(
    overrides: [
      hasOnboardedProvider.overrideWith(() => HasOnboarded(hasOnboarded)),
    ],
    child: const _AppLifecycleObserver(child: WalletApp()),
  ));
}

/// Clears the in-memory session when the application is closed (detached).
class _AppLifecycleObserver extends StatefulWidget {
  const _AppLifecycleObserver({required this.child});
  final Widget child;

  @override
  State<_AppLifecycleObserver> createState() => _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends State<_AppLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      final scope = ProviderScope.containerOf(context, listen: false);
      final store = scope.read(tokenStoreProvider);
      store.clear();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

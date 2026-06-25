import 'dart:ui';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'router/app_router.dart';
import 'services/app_settings.dart';
import 'services/firebase_providers.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ignore: deprecated_member_use
  await FirebaseAppCheck.instance.activate(
    // ignore: deprecated_member_use
    androidProvider: AndroidProvider.playIntegrity,
    // ignore: deprecated_member_use
    appleProvider: AppleProvider.appAttest,
  );

  // Push bildirimleri (FCM): izin iste, token'ı kaydet, yönlendirmeyi kur.
  await NotificationService.initialize();

  // Crashlytics: Flutter framework hatalarını ölümcül olarak kaydet.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  // Framework dışında, yakalanmayan asenkron/platform hatalarını kaydet.
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(const ProviderScope(child: CompetraApp()));
}

class CompetraApp extends ConsumerWidget {
  const CompetraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    // Oturum değiştikçe Crashlytics'e kullanıcı kimliğini ata (çıkışta temizle).
    // Böylece çökme raporları ilgili kullanıcıyla ilişkilendirilebilir.
    ref.listen(authStateProvider, (previous, next) {
      final uid = next.asData?.value?.uid;
      FirebaseCrashlytics.instance.setUserIdentifier(uid ?? '');
    });

    return MaterialApp.router(
      title: 'Competra',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: NotificationService.messengerKey,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: AppRouter.router,
    );
  }
}

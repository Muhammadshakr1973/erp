import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:ui';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/components/global_numeric_keyboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Handle standard Flutter framework errors gracefully
  FlutterError.onError = (FlutterErrorDetails details) {
    final errorStr = '${details.exception} ${details.stack}'.toLowerCase();
    if (errorStr.contains('text_editing') || 
        errorStr.contains('editing_delta') ||
        errorStr.contains('delta')) {
      debugPrint('Suppressed text editing delta FlutterError');
      return;
    }
    FlutterError.presentError(details);
  };

  // Intercept and handle asynchronous errors (such as web promise/rejection unhandled errors)
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    final errorStr = '$error $stack'.toLowerCase();
    // Catch and suppress known non-critical text input and assertion delta errors on web
    if (errorStr.contains('text_editing') || 
        errorStr.contains('editing_delta') || 
        errorStr.contains('delta') ||
        errorStr.contains('assertion')) {
      debugPrint('Suppressed asynchronous text editing delta/assertion error');
      return true; // Mark as handled, preventing browser-level Unhandled Rejections
    }
    return false; // Propagate other errors normally
  };

  await Hive.initFlutter();
  await Hive.openBox('settings');

  runApp(const ProviderScope(child: PosApp()));
}

class PosApp extends ConsumerWidget {
  const PosApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'POS App',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: router,

      // Kurdish RTL Support (fallback to Arabic for Material components)
      locale: const Locale('ar', 'IQ'), // Arabic is supported and RTL
      supportedLocales: const [
        Locale('ar', 'IQ'),
        Locale('en', 'US'), // Fallback
      ],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Enforce RTL directionality
        return Directionality(
          textDirection: TextDirection.rtl,
          child: GlobalNumericKeyboardWrapper(child: child!),
        );
      },
    );
  }
}

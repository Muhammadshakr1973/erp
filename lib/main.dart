import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'dart:ui';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/router/app_router.dart';
import 'core/components/global_numeric_keyboard.dart';
import 'features/shared/providers/notification_provider.dart';

bool _shouldIgnoreWebTextInputError(Object error, StackTrace? stack) {
  final text = '${error.toString()} ${stack ?? ''}'.toLowerCase();

  final isKnownTextInputIssue =
      text.contains('text_editing') ||
      text.contains('editing_delta') ||
      text.contains('texteditingdelta') ||
      text.contains('text input');

  final isKnownDeltaAssertion =
      text.contains('assertion') && text.contains('delta');

  return kIsWeb && (isKnownTextInputIssue || isKnownDeltaAssertion);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Handle known Flutter web text input issues without hiding unrelated app errors.
  FlutterError.onError = (FlutterErrorDetails details) {
    if (_shouldIgnoreWebTextInputError(details.exception, details.stack)) {
      debugPrint(
        'Suppressed non-critical Flutter web text input error: ${details.exception}',
      );
      return;
    }
    FlutterError.presentError(details);
  };

  // Intercept and handle asynchronous errors (such as web promise/rejection unhandled errors).
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (_shouldIgnoreWebTextInputError(error, stack)) {
      debugPrint(
        'Suppressed non-critical async Flutter web text input error: $error',
      );
      return true;
    }
    return false;
  };

  await Hive.initFlutter();
  await Hive.openBox('settings');

  runApp(const ProviderScope(child: PosApp()));
}

class PosApp extends ConsumerWidget {
  const PosApp({super.key});

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
          child: GlobalNumericKeyboardWrapper(
            child: _NotificationListenerWrapper(child: child!),
          ),
        );
      },
    );
  }
}

class _NotificationListenerWrapper extends ConsumerWidget {
  final Widget child;
  const _NotificationListenerWrapper({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep notifications list provider active continuously so notifications arrive live
    ref.watch(notificationsListProvider);
    return child;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'services/cloud_sync_service.dart';
import 'services/firebase_bootstrap_service.dart';
import 'storage/hive_service.dart';
import 'screens/main_navigation_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Hive.initFlutter();

  final storage = HiveService();
  final firebaseBootstrapService = FirebaseBootstrapService();
  final cloudSyncService = CloudSyncService(firebaseBootstrapService);
  await storage.init();

  final appState = AppState(
    storage,
    cloudSync: cloudSyncService,
    firebaseBootstrapService: firebaseBootstrapService,
  );
  await appState.init();

  runApp(
    ChangeNotifierProvider.value(value: appState, child: const TapoTeaApp()),
  );
}

class TapoTeaApp extends StatelessWidget {
  const TapoTeaApp({super.key});

  ThemeData _theme(Brightness brightness) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: const Color(0xFFE75AA7),
    );
    final darkBackground = const Color(0xFF232323);
    final darkSurface = const Color(0xFF2D2D2D);
    const roundedFallback = ['SF Pro Rounded', 'SF UI Rounded', 'SF Pro Text'];
    final scheme = brightness == Brightness.dark
        ? base.colorScheme.copyWith(
            surface: darkSurface,
            surfaceContainer: const Color(0xFF292929),
            surfaceContainerHigh: const Color(0xFF313131),
            surfaceContainerHighest: const Color(0xFF383838),
          )
        : base.colorScheme;
    TextStyle? relax(
      TextStyle? style, {
      double? fontSize,
      FontWeight? fontWeight,
      double? height,
      double? letterSpacing,
    }) {
      if (style == null) return null;
      return style.copyWith(
        fontFamilyFallback: roundedFallback,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
      );
    }

    final textTheme = base.textTheme.copyWith(
      displayLarge: relax(
        base.textTheme.displayLarge,
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      displayMedium: relax(
        base.textTheme.displayMedium,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.08,
      ),
      displaySmall: relax(
        base.textTheme.displaySmall,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.05,
      ),
      headlineLarge: relax(
        base.textTheme.headlineLarge,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.02,
      ),
      headlineMedium: relax(
        base.textTheme.headlineMedium,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      headlineSmall: relax(
        base.textTheme.headlineSmall,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.02,
      ),
      titleLarge: relax(
        base.textTheme.titleLarge,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.02,
      ),
      titleMedium: relax(
        base.textTheme.titleMedium,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.03,
      ),
      titleSmall: relax(
        base.textTheme.titleSmall,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.04,
      ),
      bodyLarge: relax(
        base.textTheme.bodyLarge,
        fontSize: 15,
        height: 1.42,
        letterSpacing: 0.02,
      ),
      bodyMedium: relax(
        base.textTheme.bodyMedium,
        fontSize: 14,
        height: 1.42,
        letterSpacing: 0.02,
      ),
      bodySmall: relax(
        base.textTheme.bodySmall,
        fontSize: 12,
        height: 1.35,
        letterSpacing: 0.03,
      ),
      labelLarge: relax(
        base.textTheme.labelLarge,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.04,
      ),
      labelMedium: relax(
        base.textTheme.labelMedium,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.05,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      scaffoldBackgroundColor: brightness == Brightness.dark
          ? darkBackground
          : Colors.white,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.headlineMedium?.copyWith(
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: brightness == Brightness.dark ? darkSurface : scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: brightness == Brightness.dark
              ? scheme.primaryContainer
              : scheme.primary,
          foregroundColor: brightness == Brightness.dark
              ? scheme.onPrimaryContainer
              : scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(textStyle: textTheme.labelLarge),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.dark
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.55)
            : scheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surfaceContainerHighest,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.55),
        thickness: 1,
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary.withValues(alpha: 0.65);
          }
          return scheme.surfaceContainerHighest;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return brightness == Brightness.dark
                ? scheme.surface
                : Colors.white;
          }
          return scheme.outline;
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return MaterialApp(
      title: 'Taro Tea',
      debugShowCheckedModeBanner: false,
      themeMode: appState.themeMode,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const MainNavigationScreen(),
    );
  }
}

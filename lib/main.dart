import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io' show Platform;
import 'services/database_service.dart';
import 'services/localization_service.dart';
import 'screens/main_screen.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// For window sizing on desktop platforms
import 'package:flutter/foundation.dart';
import 'package:window_size/window_size.dart' as window_size;

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize localization service
  await LocalizationService.init();
  
  // Debug: Log all loaded keys to verify translations are loaded correctly
  LocalizationService.logAllKeys();
  
  // Set window size for desktop platforms
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    // Import the functions directly from the window_size package
    try {
      window_size.getWindowInfo().then((window) {
        final screenSize = window_size.getWindowInfo().then((window) {
          final screen = window.screen;
          if (screen != null) {
            return screen.visibleFrame;
          }
          return const Rect.fromLTWH(0.0, 0.0, 1200.0, 800.0);
        });
        
        // Set window title
        window_size.setWindowTitle('Flowers Fit Üyelik Takibi');
        
        // Set window minimum size
        window_size.setWindowMinSize(const Size(1200, 800));
        
        // Set window size
        screenSize.then((screen) {
          // Make app window 75% of screen size
          final width = screen.width * 0.75;
          final height = screen.height * 0.75;
          window_size.setWindowFrame(
            Rect.fromCenter(
              center: Offset(screen.center.dx, screen.center.dy),
              width: width,
              height: height,
            ),
          );
        });
      });
    } catch (e) {
      print('Error setting window size: $e');
    }
  }
  
  // Initialize database
  final databaseService = DatabaseService();
  final db = await databaseService.database;
  
  // Run the app
  runApp(GymMembershipApp(database: db));
}

class GymMembershipApp extends StatelessWidget {
  final Database database;
  
  const GymMembershipApp({Key? key, required this.database}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'appTitle'.tr,
      // Add localization support
      locale: const Locale('tr', 'TR'), // Set Turkish as the default locale
      supportedLocales: const [
        Locale('tr', 'TR'), // Turkish
        Locale('en', 'US'), // English as a fallback
      ],
      // Add localization delegates
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        primarySwatch: Colors.blue,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.light,
        ),
        // Increase the default text sizes
        textTheme: Typography.englishLike2018.apply(
          fontSizeFactor: 1.2, // Increase all text sizes by 20%
          displayColor: Colors.black,
          bodyColor: Colors.black,
        ),
        // Increase the default icon sizes
        iconTheme: const IconThemeData(size: 24), // Default is 24, increase as needed
        useMaterial3: true,
        // Increase default padding/spacing
        cardTheme: const CardTheme(
          margin: EdgeInsets.all(12.0), // Increase from default 4.0 or 8.0
        ),
        // Increase list tile spacing
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        ),
        // Larger buttons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
        // Page transitions theme
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        // Increase the default text sizes for dark theme too
        textTheme: Typography.englishLike2018.apply(
          fontSizeFactor: 1.2, // Increase all text sizes by 20%
          displayColor: Colors.white,
          bodyColor: Colors.white,
        ),
        // Increase the default icon sizes
        iconTheme: const IconThemeData(size: 24), // Default is 24, increase as needed
        useMaterial3: true,
        // Increase default padding/spacing
        cardTheme: const CardTheme(
          margin: EdgeInsets.all(12.0), // Increase from default 4.0 or 8.0
        ),
        // Increase list tile spacing
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        ),
        // Larger buttons
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
        // Page transitions theme
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          },
        ),
      ),
      themeMode: ThemeMode.system,
      // Builder for default styles
      builder: (context, child) {
        return DefaultTextStyle(
          style: Theme.of(context).textTheme.bodyMedium!,
          child: child!,
        );
      },
      home: MainScreen(database: database),
    );
  }
}
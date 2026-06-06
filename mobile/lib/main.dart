import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'utils/auth_store.dart';
import 'utils/fcm_service.dart';
import 'utils/theme.dart';
import 'utils/theme_provider.dart';
import 'router.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await Firebase.initializeApp();
  await ThemeProvider().load();
  await AuthStore().load();
  if (AuthStore().isLoggedIn) await FcmService.init();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  await AuthStore().load();
  runApp(const WogetherApp());
}

class WogetherApp extends StatefulWidget {
  const WogetherApp({super.key});

  @override
  State<WogetherApp> createState() => _WogetherAppState();
}

class _WogetherAppState extends State<WogetherApp> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeProvider(),
      builder: (context, _) {
        final theme = buildDynamicTheme(ThemeProvider());
        final themeMode = ThemeProvider().isLight ? ThemeMode.light : ThemeMode.dark;
        if (_showSplash) {
          return MaterialApp(
            title: '워게더',
            theme: theme,
            themeMode: themeMode,
            debugShowCheckedModeBanner: false,
            home: SplashScreen(onDone: () => setState(() => _showSplash = false)),
          );
        }
        return ListenableBuilder(
          listenable: AuthStore(),
          builder: (context, _) => MaterialApp.router(
            title: '워게더',
            theme: theme,
            themeMode: themeMode,
            routerConfig: router,
            debugShowCheckedModeBanner: false,
          ),
        );
      },
    );
  }
}

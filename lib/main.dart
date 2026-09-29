import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/ads/ad_manager.dart';
import 'core/ads/consent_manager.dart';
import 'core/analytics.dart';
import 'core/live_config.dart';
import 'core/progress.dart';
import 'core/purchases.dart';
import 'core/sound.dart';
import 'core/strings.dart';
import 'firebase_options.dart';
import 'game/eat_game.dart';
import 'ui/main_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
    ),
  );

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    Analytics.instance.attach();
    await LiveConfig.instance.attach();
  } catch (e) {
    debugPrint('Firebase not configured: $e');
  }

  final progress = await Progress.load();
  Sound.instance
    ..sfxOn = progress.sound
    ..hapticsOn = progress.haptics
    ..musicOn = progress.music;
  // The sprite atlas is painted while the first frame goes up.
  EatGame.loadAtlas();

  runApp(ChangeNotifierProvider.value(value: progress, child: const EatUpApp()));

  // Audio, purchases and ads warm up behind the first frame. Consent comes
  // first so no ad request ever goes out without a consent choice behind it.
  Sound.instance.init();
  Purchases.instance.init(progress);
  await ConsentManager().gather();
  await AdManager.instance.startIfAllowed();
}

class EatUpApp extends StatelessWidget {
  const EatUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    final code = context.select<Progress, String?>((p) => p.localeCode);
    return MaterialApp(
      title: 'EatUp',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: code == null ? null : Locale(code),
      supportedLocales: [for (final c in Strings.languages) Locale(c)],
      localizationsDelegates: const [
        Strings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Keep huge accessibility font sizes from breaking game layouts while
        // still honouring moderate scaling.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.15)),
          child: child!,
        );
      },
      home: const MainScreen(),
    );
  }
}

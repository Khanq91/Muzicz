import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide ChangeNotifierProvider;
import 'package:muziczz/providers/theme_provider.dart';
import 'package:muziczz/widgets/theme_switch_wrapper.dart';
import 'package:provider/provider.dart';
import 'features/downloader/core/app_router.dart';
import 'providers/music_provider.dart';
import 'providers/player_provider.dart';
import 'screens/splash_screen.dart';
import 'services/audio_handler.dart';
import 'theme/app_theme.dart';
import 'package:just_audio_background/just_audio_background.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.muziczz.muziczz.channel.audio',
    androidNotificationChannelName: 'Muziczz Audio',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final audioHandler = MuzicAudioHandler();
  // runApp(MuzicApp(audioHandler: audioHandler));
  runApp(
    ProviderScope(
      child: ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: MuzicApp(audioHandler: audioHandler),
      ),
    ),
  );
}


class MuzicApp extends StatelessWidget {
  const MuzicApp({super.key, required this.audioHandler});
  final MuzicAudioHandler audioHandler;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MusicProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider(audioHandler)),
      ],
      child: MaterialApp(
        title: 'Muzicz Audio',
        debugShowCheckedModeBanner: false,
        theme: themeProvider.themeData,
        themeAnimationDuration: const Duration(milliseconds: 300),
        themeAnimationCurve: Curves.easeInOut,
        onGenerateRoute: (settings) {
          // ytdlp routes
          if (settings.name?.startsWith('/dl/') == true) {
            return AppRouter.onGenerateRoute(settings);
          }
          return null;
        },
        home: const SplashScreen(),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                MediaQuery.of(context).textScaleFactor.clamp(0.85, 1.15),
              ),
            ),
            // child: child!,
            child: ThemeSwitchWrapper(child: child!),
          );
        },
      ),
    );
  }
}

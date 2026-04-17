import 'dart:async';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:squad/screens/feed_screen.dart';
import 'package:squad/screens/reset_password_screen.dart';
import 'package:squad/utils/app_localizations.dart';
import 'package:squad/utils/language_provider.dart';
import 'package:squad/providers/theme_provider.dart';
import 'package:squad/screens/splash_screen.dart';
import 'package:squad/widgets/global_double_back_exit.dart';
import 'package:squad/providers/notification_provider.dart';
import 'package:squad/screens/player_profile_screen.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:video_player_android/video_player_android.dart';

final GlobalKey<NavigatorState> appNavKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final androidImplementation = VideoPlayerPlatform.instance;



  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [
      SystemUiOverlay.top,
      SystemUiOverlay.bottom,
    ],
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();

    _linkSub = _appLinks.uriLinkStream.listen((uri) {
      final token = uri.queryParameters['token'];
      final path = uri.path.toLowerCase();

      // Expect: https://squad-player.app/reset?token=...
      if (token != null && token.isNotEmpty && path.contains('reset')) {
        final ctx = appNavKey.currentContext;
        if (ctx == null) return;

        Navigator.of(ctx).push(
          MaterialPageRoute(builder: (_) => ResetPasswordScreen(token: token)),
        );
      }
    });

    // Register deep link listeners for posts and profiles.
    // Without this call, links like squad://profile/123 or squad://post/456
    // will launch the app but not navigate to the correct screen.
    initDeepLinks();
  }


  void initDeepLinks(){
    _appLinks.uriLinkStream.listen((uri) {
      // Use the navigatorKey's context to navigate. The context on this state
      // does not have access to a Navigator until after MaterialApp builds.
      final ctx = appNavKey.currentContext;
      if (ctx == null) return;

      // Determine whether the path contains 'post' or 'profile' and extract the ID.
      // When using a custom scheme like squad://profile/308, the `host` holds the
      // route segment ('profile' or 'post') and the path segment contains the ID.
      final host = uri.host.toLowerCase();
      final idStr = (uri.pathSegments.isNotEmpty) ? uri.pathSegments.last : null;
      final id = idStr != null ? int.tryParse(idStr) : null;
      if (id == null) return;

      if (host == 'post') {
        // Navigate to the feed screen or post details as appropriate.
        Navigator.of(ctx).push(
          MaterialPageRoute(builder: (_) => FeedScreen()),
        );
      } else if (host == 'profile') {
        // Navigate to the player's profile screen using the provided ID.
        Navigator.of(ctx).push(
          MaterialPageRoute(builder: (_) => PlayerProfileScreen(userId: id)),
        );
      }
    });

  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(

      providers: [
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()..start()),
      ],

      child: Consumer2<LanguageProvider, ThemeProvider>(
        builder: (context, languageProvider, themeProvider, child) {

          return ScreenUtilInit(
            designSize: const Size(390, 844),
            minTextAdapt: true,
            builder: (context, child) {
              return MaterialApp(
                navigatorKey: appNavKey,
                title: 'إسكواد',
                debugShowCheckedModeBanner: false,

                theme: ThemeProvider.lightTheme,
                darkTheme: ThemeProvider.darkTheme,
                themeMode: themeProvider.themeMode,

                locale: languageProvider.locale,

                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],

                supportedLocales: const [
                  Locale('en', ''),
                  Locale('ar', ''),
                ],

                builder: (context, child) {
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaleFactor: 1.0,
                    ),
                    child: GlobalDoubleBackExit(
                      message: AppLocalizations.of(context)?.tr('press_back_again_exit') ??
                          'Press back again to exit',
                      child: child ?? const SizedBox.shrink(),
                    ),
                  );
                },

                home: const SplashScreen(),
              );
            },
          );
        },
      ),
    );
  }
}
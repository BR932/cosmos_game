import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'audio/game_audio_controller.dart';
import 'config/config_coordinator.dart';
import 'connectivity_service.dart';
import 'game.dart';
import 'progress_storage.dart';
import 'system_ui_config.dart';
import 'ui/config_webview_screen.dart';
import 'ui/game_hud.dart';
import 'ui/game_over.dart';
import 'ui/loading_screen.dart';
import 'ui/offline_screen.dart';
import 'ui/start_menu.dart';
import 'ui/winner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await configureImmersiveSystemUi();
  await ProgressStorage.instance.init();
  await ConnectivityService.instance.init();

  runApp(const CyberRunnerApp());
}

class CyberRunnerApp extends StatelessWidget {
  const CyberRunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF00E5FF),
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );

    return ImmersiveSystemUiScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Egg Escape',
        theme: baseTheme.copyWith(
          textTheme: GoogleFonts.moulTextTheme(baseTheme.textTheme),
          primaryTextTheme: GoogleFonts.moulTextTheme(
            baseTheme.primaryTextTheme,
          ),
          snackBarTheme: SnackBarThemeData(
            contentTextStyle: GoogleFonts.moul(color: Colors.white),
          ),
        ),
        home: const _GameShell(),
      ),
    );
  }
}

class _GameShell extends StatefulWidget {
  const _GameShell();

  @override
  State<_GameShell> createState() => _GameShellState();
}

class _GameShellState extends State<_GameShell> with WidgetsBindingObserver {
  CyberRunnerGame? _game;
  bool _showLoading = true;
  bool _offlineScreenDismissed = false;
  String? _configWebViewUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ConnectivityService.instance.isOffline.addListener(_onConnectivityChanged);
    _finishLoadingScreen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ConnectivityService.instance.isOffline.removeListener(
      _onConnectivityChanged,
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    GameAudioController.instance.handleAppLifecycleChange(state);
  }

  void _onConnectivityChanged() {
    if (!mounted) {
      return;
    }

    if (!ConnectivityService.instance.isOffline.value) {
      _offlineScreenDismissed = false;
    }

    setState(() {});
  }

  Future<void> _finishLoadingScreen() async {
    final loadingStarted = DateTime.now();

    final results = await Future.wait<Object?>([
      ConnectivityService.instance.waitForReliableCheck(
        timeout: LoadingScreen.displayDuration + const Duration(seconds: 3),
      ),
      ConfigCoordinator.instance.resolveLaunchDecision(),
    ]);
    final decision = results[1]! as ConfigLaunchDecision;

    final elapsed = DateTime.now().difference(loadingStarted);
    final remaining = LoadingScreen.displayDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _showLoading = false;
      if (decision.target == ConfigLaunchTarget.webView) {
        _configWebViewUrl = decision.url;
      }
    });
  }

  void _exitConfigWebView() {
    setState(() {
      _configWebViewUrl = null;
    });
  }

  Future<void> _startGame() async {
    await GameAudioController.instance.playTransitionSound();
    setState(() {
      _game = CyberRunnerGame(onExitToMenu: _exitToMenu);
    });
  }

  Future<void> _exitToMenu() async {
    await GameAudioController.instance.playTransitionSound();
    if (!mounted) {
      return;
    }
    setState(() {
      _game = null;
    });
  }

  Future<void> _handleOfflineBack() async {
    await GameAudioController.instance.playButtonSound();
    if (!mounted) {
      return;
    }
    setState(() {
      _game = null;
      _showLoading = true;
      _offlineScreenDismissed = true;
    });
    await _finishLoadingScreen();
  }

  @override
  Widget build(BuildContext context) {
    if (_showLoading) {
      return const LoadingScreen();
    }

    final configUrl = _configWebViewUrl;
    if (configUrl != null) {
      return ConfigWebViewScreen(
        url: configUrl,
        onExit: _exitConfigWebView,
      );
    }

    final game = _game;

    if (game != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF050713),
        body: SafeArea(
          top: false,
          bottom: false,
          child: GameWidget<CyberRunnerGame>(
            game: game,
            initialActiveOverlays: const <String>[GameHud.overlayId],
            overlayBuilderMap: <String, OverlayWidgetBuilder<CyberRunnerGame>>{
              GameHud.overlayId: (context, game) => GameHud(game: game),
              GameOverOverlay.overlayId: (context, game) =>
                  GameOverOverlay(game: game),
              WinnerOverlay.overlayId: (context, game) =>
                  WinnerOverlay(game: game),
            },
          ),
        ),
      );
    }

    final isOffline = ConnectivityService.instance.isOffline.value;

    if (isOffline && !_offlineScreenDismissed) {
      return OfflineScreen(onBack: _handleOfflineBack);
    }

    return StartMenu(onStart: _startGame);
  }
}

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game.dart';
import 'ui/game_hud.dart';
import 'ui/game_over.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const CyberRunnerApp());
}

class CyberRunnerApp extends StatelessWidget {
  const CyberRunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Neon Lane Runner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF050713),
        body: SafeArea(
          top: false,
          bottom: false,
          child: GameWidget<CyberRunnerGame>(
            game: CyberRunnerGame(),
            initialActiveOverlays: const <String>[GameHud.overlayId],
            overlayBuilderMap: <String, OverlayWidgetBuilder<CyberRunnerGame>>{
              GameHud.overlayId: (context, game) => GameHud(game: game),
              GameOverOverlay.overlayId: (context, game) =>
                  GameOverOverlay(game: game),
            },
          ),
        ),
      ),
    );
  }
}

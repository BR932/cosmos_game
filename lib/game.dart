import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'lane_manager.dart';
import 'obstacle.dart';
import 'player_car.dart';
import 'ui/game_over.dart';

class CyberRunnerGame extends FlameGame with HasCollisionDetection {
  CyberRunnerGame()
    : lanes = LaneManager(),
      stars = ValueNotifier<int>(0),
      bestStars = ValueNotifier<int>(0),
      isGameOver = ValueNotifier<bool>(false);

  static const String _bestScoreKey = 'best_stars';

  final LaneManager lanes;
  final ValueNotifier<int> stars;
  final ValueNotifier<int> bestStars;
  final ValueNotifier<bool> isGameOver;

  late final Sprite playerSprite;
  late final Sprite obstacleSprite;
  late PlayerCar player;
  late RoadComponent road;

  final math.Random _random = math.Random();
  SharedPreferences? _preferences;

  double _distance = 0;
  double _spawnTimer = 0;
  double _elapsed = 0;
  bool _runIsActive = true;

  double obstacleSpeed = 250;

  Vector2 get playerSize {
    final width = lanes.normalizedCarWidth();
    return Vector2(width, width * 1.72);
  }

  Vector2 get obstacleSize {
    final width = lanes.normalizedObstacleWidth();
    return Vector2(width, width * 1.18);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    lanes.resize(size);

    _preferences = await SharedPreferences.getInstance();
    bestStars.value = _preferences?.getInt(_bestScoreKey) ?? 0;

    // Sprites are generated once at startup so the components can still use
    // Flame's SpriteComponent pipeline without requiring external art files.
    playerSprite = Sprite(await _createPlayerSprite());
    obstacleSprite = Sprite(await _createObstacleSprite());

    road = RoadComponent();
    add(road);

    _createPlayer();
  }

  @override
  Color backgroundColor() => const Color(0xFF050713);

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    lanes.resize(size);

    if (isLoaded) {
      road.applyLayout();
      if (player.isMounted) {
        player.applyLayout();
      }
      for (final obstacle in children.whereType<Obstacle>()) {
        obstacle.applyLayout();
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_runIsActive) {
      return;
    }

    // Distance is the single progression source: it awards stars, raises
    // obstacle speed, and indirectly compresses spawn timing over time.
    _elapsed += dt;
    obstacleSpeed = 250 + (_elapsed * 9);
    _distance += obstacleSpeed * dt;

    final nextStars = _distance ~/ 90;
    if (nextStars != stars.value) {
      stars.value = nextStars;
    }

    _spawnTimer -= dt;
    if (_spawnTimer <= 0) {
      _spawnObstacle();
      _spawnTimer = _nextSpawnDelay();
    }
  }

  void moveLeft() {
    if (_runIsActive) {
      player.moveToLane(player.lane - 1);
    }
  }

  void moveRight() {
    if (_runIsActive) {
      player.moveToLane(player.lane + 1);
    }
  }

  Future<void> restart() async {
    overlays.remove(GameOverOverlay.overlayId);
    for (final obstacle in children.whereType<Obstacle>().toList()) {
      obstacle.removeFromParent();
    }

    _distance = 0;
    _elapsed = 0;
    _spawnTimer = 0.45;
    obstacleSpeed = 250;
    stars.value = 0;
    isGameOver.value = false;
    _runIsActive = true;

    player
      ..lane = lanes.laneCount ~/ 2
      ..applyLayout();
  }

  Future<void> endRun() async {
    if (!_runIsActive) {
      return;
    }

    _runIsActive = false;
    isGameOver.value = true;

    if (stars.value > bestStars.value) {
      bestStars.value = stars.value;
      await _preferences?.setInt(_bestScoreKey, bestStars.value);
    }

    overlays.add(GameOverOverlay.overlayId);
  }

  void _createPlayer() {
    final startLane = lanes.laneCount ~/ 2;
    player = PlayerCar(
      sprite: playerSprite,
      lane: startLane,
      position: lanes.playerStartPosition(startLane),
      size: playerSize,
    );
    add(player);
  }

  void _spawnObstacle() {
    final lane = _random.nextInt(lanes.laneCount);
    final position = Vector2(
      lanes.laneCenterX(lane),
      lanes.roadRect.top - obstacleSize.y,
    );
    add(
      Obstacle(
        sprite: obstacleSprite,
        lane: lane,
        position: position,
        size: obstacleSize,
      ),
    );
  }

  double _nextSpawnDelay() {
    final maxDelay = math.max(0.38, 1.05 - (_elapsed * 0.012));
    final minDelay = math.max(0.2, 0.55 - (_elapsed * 0.006));
    return minDelay + (_random.nextDouble() * (maxDelay - minDelay));
  }

  Future<ui.Image> _createPlayerSprite() async {
    const width = 96;
    const height = 168;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final glowPaint = Paint()
      ..color = const Color(0xAA00E5FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Color(0xFF0DEBFF), Color(0xFF8B5CF6)],
      ).createShader(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
    final glassPaint = Paint()..color = const Color(0xCC03111F);
    final trimPaint = Paint()
      ..color = const Color(0xFFFF2BD6)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    final bodyPath = Path()
      ..moveTo(width * 0.5, 6)
      ..lineTo(width * 0.82, height * 0.26)
      ..lineTo(width * 0.9, height * 0.78)
      ..lineTo(width * 0.68, height - 8)
      ..lineTo(width * 0.32, height - 8)
      ..lineTo(width * 0.1, height * 0.78)
      ..lineTo(width * 0.18, height * 0.26)
      ..close();

    canvas.drawPath(bodyPath, glowPaint);
    canvas.drawPath(bodyPath, bodyPaint);
    canvas.drawPath(bodyPath, trimPaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(28, 34, 40, 52),
        const Radius.circular(12),
      ),
      glassPaint,
    );
    canvas.drawLine(
      const Offset(20, 112),
      const Offset(76, 112),
      Paint()
        ..color = const Color(0xFFFFF176)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    final picture = recorder.endRecording();
    return picture.toImage(width, height);
  }

  Future<ui.Image> _createObstacleSprite() async {
    const width = 110;
    const height = 128;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final glowPaint = Paint()
      ..color = const Color(0x99FF2BD6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    final corePaint = Paint()
      ..shader = const RadialGradient(
        colors: <Color>[Color(0xFFFFF176), Color(0xFFFF2BD6)],
      ).createShader(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));
    final edgePaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke;

    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(18, 18, 74, 92),
      const Radius.circular(18),
    );
    canvas.drawRRect(body, glowPaint);
    canvas.drawRRect(body, corePaint);
    canvas.drawRRect(body, edgePaint);
    canvas.drawCircle(
      const Offset(55, 64),
      18,
      Paint()..color = const Color(0xDD050713),
    );
    canvas.drawLine(
      const Offset(32, 32),
      const Offset(78, 96),
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    final picture = recorder.endRecording();
    return picture.toImage(width, height);
  }
}

class RoadComponent extends Component with HasGameReference<CyberRunnerGame> {
  final Paint _roadPaint = Paint()..color = const Color(0xFF080B1D);
  final Paint _edgeGlowPaint = Paint()
    ..color = const Color(0x9900E5FF)
    ..strokeWidth = 5
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
  final Paint _edgePaint = Paint()
    ..color = const Color(0xFF00E5FF)
    ..strokeWidth = 2.5;
  final Paint _lanePaint = Paint()
    ..color = const Color(0xCCFF2BD6)
    ..strokeWidth = 2;
  final Paint _dashPaint = Paint()
    ..color = const Color(0xAAFFF176)
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round;
  final Paint _starPaint = Paint()..color = const Color(0x6600E5FF);

  double _scroll = 0;

  @override
  int get priority => 0;

  @override
  void update(double dt) {
    super.update(dt);
    _scroll = (_scroll + game.obstacleSpeed * dt) % 72;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final rect = game.lanes.roadRect;

    _drawBackgroundParticles(canvas);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      _roadPaint,
    );

    _drawRoadEdges(canvas, rect);
    _drawLaneLines(canvas, rect);
    _drawMovingDashes(canvas, rect);
  }

  void applyLayout() {}

  void _drawBackgroundParticles(Canvas canvas) {
    for (var i = 0; i < 34; i++) {
      final x = ((i * 97) % game.size.x.toInt()).toDouble();
      final y = ((i * 173 + _scroll * 1.7) % game.size.y).toDouble();
      canvas.drawCircle(Offset(x, y), i.isEven ? 1.4 : 0.8, _starPaint);
    }
  }

  void _drawRoadEdges(Canvas canvas, Rect rect) {
    canvas.drawLine(rect.topLeft, rect.bottomLeft, _edgeGlowPaint);
    canvas.drawLine(rect.topRight, rect.bottomRight, _edgeGlowPaint);
    canvas.drawLine(rect.topLeft, rect.bottomLeft, _edgePaint);
    canvas.drawLine(rect.topRight, rect.bottomRight, _edgePaint);
  }

  void _drawLaneLines(Canvas canvas, Rect rect) {
    for (var lane = 1; lane < game.lanes.laneCount; lane++) {
      final x = rect.left + game.lanes.laneWidth * lane;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), _lanePaint);
    }
  }

  void _drawMovingDashes(Canvas canvas, Rect rect) {
    for (var lane = 0; lane < game.lanes.laneCount; lane++) {
      final centerX = game.lanes.laneCenterX(lane);
      for (var y = rect.top - 72 + _scroll; y < rect.bottom; y += 72) {
        canvas.drawLine(
          Offset(centerX, y),
          Offset(centerX, y + 22),
          _dashPaint,
        );
      }
    }
  }
}

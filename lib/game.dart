import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'audio/game_audio_controller.dart';
import 'lane_manager.dart';
import 'obstacle.dart';
import 'player_car.dart';
import 'progress_storage.dart';
import 'ui/game_over.dart';
import 'ui/winner.dart';

class CyberRunnerGame extends FlameGame with HasCollisionDetection {
  CyberRunnerGame({required this.onExitToMenu})
    : lanes = LaneManager(),
      stars = ValueNotifier<int>(0),
      bestStars = ProgressStorage.instance.bestStars,
      isGameOver = ValueNotifier<bool>(false);

  final LaneManager lanes;
  final ValueNotifier<int> stars;
  final ValueNotifier<int> bestStars;
  final ValueNotifier<bool> isGameOver;
  final Future<void> Function() onExitToMenu;

  late final Sprite playerSprite;

  // Бонусы (Яйца)
  late final Sprite eggJuniorSprite;
  late final Sprite eggMiddleSprite;
  late final Sprite eggSuperSprite;

  // Препятствия
  late final Sprite obstacle1Sprite;
  late final Sprite obstacle2Sprite;
  late final Sprite obstacle3Sprite;
  late final Sprite obstacle4Sprite;

  late PlayerCar player;
  late RoadComponent road;

  final math.Random _random = math.Random();

  double _distance = 0;
  double _spawnTimer = 0;
  double _elapsed = 0;
  bool _runIsActive = true;

  int _scoreModifier = 0;
  double obstacleSpeed = 250;

  // --- Независимые таймеры для бонусов (Яиц) ---
  double _eggJuniorCooldown =
      4.0; // Сделали 4 секунды вместо 10, чтобы появлялось часто
  double _eggMiddleCooldown = 20.0;
  double _eggSuperCooldown = 30.0;

  Vector2 get playerSize {
    final width = lanes.normalizedCarWidth();
    return Vector2(width, width * 1.72) * 1.4;
  }

  Vector2 get obstacleSize {
    final width = lanes.normalizedObstacleWidth();
    return Vector2(width, width * 1.18);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    lanes.resize(size);

    playerSprite = await loadSprite('object_for_line.png');

    // Загрузка бонусов
    eggJuniorSprite = await loadSprite('egg_junior.png');
    eggMiddleSprite = await loadSprite('egg_middle.png');
    eggSuperSprite = await loadSprite('egg_super.png');

    // Загрузка препятствий
    obstacle1Sprite = await loadSprite('obstacles_1.png');
    obstacle2Sprite = await loadSprite('obstacles_2.png');
    obstacle3Sprite = await loadSprite('obstacles_3.png');
    obstacle4Sprite = await loadSprite('obstacles_4.png');

    road = RoadComponent();
    add(road);

    _createPlayer();

    // Первичная инициализация случайных интервалов
    _eggMiddleCooldown = 20.0 + _random.nextDouble() * 5.0; // 20-25 секунд
    _eggSuperCooldown = 30.0 + _random.nextDouble() * 10.0; // 30-40 секунд
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
    if (!_runIsActive) return;

    _elapsed += dt;
    obstacleSpeed = math.min(650, 250 + (_elapsed * 9));
    _distance += obstacleSpeed * dt;

    // ИЗМЕНЕНИЕ: Очки теперь зависят ИСКЛЮЧИТЕЛЬНО от пойманных бонусов (_scoreModifier).
    // Больше пройденное расстояние не добавляет очки автоматически.
    final nextStars = _scoreModifier;

    if (nextStars != stars.value) {
      stars.value = nextStars;
    }

    // Проверяем, наступила ли фаза ускорения (скорость > 500)
    final isAccelerated = obstacleSpeed > 500;

    // 1. Появление обычных препятствий
    _spawnTimer -= dt;
    if (_spawnTimer <= 0) {
      _spawnObstacle(isAccelerated);
      _spawnTimer = _nextSpawnDelay();
    }

    // 2. Таймер Egg Junior: Появляется ЧАСТО (каждые 4 секунды по 2 штуки в любом режиме)
    _eggJuniorCooldown -= dt;
    if (_eggJuniorCooldown <= 0) {
      _spawnEggJunior(2);
      _eggJuniorCooldown = 4.0; // Возвращаем кулдаун в 4 секунды
    }

    // 3. Таймер Egg Middle: 1 штука каждые 20-25 секунд (работает всегда)
    _eggMiddleCooldown -= dt;
    if (_eggMiddleCooldown <= 0) {
      _spawnBonusEgg(eggMiddleSprite, 45); // ИЗМЕНЕНИЕ: Теперь дает +45 очков
      _eggMiddleCooldown = 20.0 + _random.nextDouble() * 5.0;
    }

    // 4. Таймер Egg Super: 1 штука каждые 30-40 секунд (ТОЛЬКО после ускорения)
    if (isAccelerated) {
      _eggSuperCooldown -= dt;
      if (_eggSuperCooldown <= 0) {
        _spawnBonusEgg(eggSuperSprite, 85); // ИЗМЕНЕНИЕ: Теперь дает +85 очков
        _eggSuperCooldown = 30.0 + _random.nextDouble() * 10.0;
      }
    }
  }

  void modifyScore(int value) {
    if (!_runIsActive) return;

    _scoreModifier += value;

    // ИЗМЕНЕНИЕ: Обновляем счет только на основе модификатора от ловли предметов
    stars.value = _scoreModifier;

    if (stars.value < 0) {
      endRun();
    }
  }

  // Спавн обычных препятствий (минус очки)
  void _spawnObstacle(bool isAccelerated) {
    final lane = _random.nextInt(lanes.laneCount);
    final position = Vector2(
      lanes.laneCenterX(lane),
      lanes.roadRect.top - obstacleSize.y,
    );

    Sprite selectedSprite;
    int scoreValue;

    if (isAccelerated) {
      // ПОСЛЕ УСКОРЕНИЯ: Могут появляться все препятствия (1, 2, 3, 4)
      final rand = _random.nextInt(100);
      if (rand < 30) {
        selectedSprite = obstacle1Sprite;
        scoreValue = -10;
      } else if (rand < 60) {
        selectedSprite = obstacle2Sprite;
        scoreValue = -15;
      } else if (rand < 80) {
        selectedSprite = obstacle4Sprite;
        scoreValue = -20;
      } else {
        selectedSprite = obstacle3Sprite;
        scoreValue = -35;
      }
    } else {
      // ДО УСКОРЕНИЯ: Только частые obstacles_1 и obstacles_2
      final rand = _random.nextBool();
      if (rand) {
        selectedSprite = obstacle1Sprite;
        scoreValue = -10;
      } else {
        selectedSprite = obstacle2Sprite;
        scoreValue = -15;
      }
    }

    add(
      Obstacle(
        sprite: selectedSprite,
        lane: lane,
        position: position,
        size: obstacleSize,
        scoreChange: scoreValue,
        endsRunOnCollision:
            selectedSprite == obstacle1Sprite ||
            selectedSprite == obstacle3Sprite,
      ),
    );
  }

  // Спавн сразу 2 штук Egg Junior в разные случайные полосы
  void _spawnEggJunior(int count) {
    List<int> availableLanes = List.generate(lanes.laneCount, (i) => i);
    availableLanes.shuffle(_random);

    for (int i = 0; i < math.min(count, lanes.laneCount); i++) {
      final lane = availableLanes[i];
      final position = Vector2(
        lanes.laneCenterX(lane),
        lanes.roadRect.top - obstacleSize.y,
      );
      add(
        Obstacle(
          sprite: eggJuniorSprite,
          lane: lane,
          position: position,
          size: obstacleSize,
          scoreChange: 12,
        ),
      );
    }
  }

  // Спавн одиночного среднего или супер-яйца
  void _spawnBonusEgg(Sprite sprite, int scoreChange) {
    final lane = _random.nextInt(lanes.laneCount);
    final position = Vector2(
      lanes.laneCenterX(lane),
      lanes.roadRect.top - obstacleSize.y,
    );
    add(
      Obstacle(
        sprite: sprite,
        lane: lane,
        position: position,
        size: obstacleSize,
        scoreChange: scoreChange,
      ),
    );
  }

  void moveLeft() {
    if (_runIsActive) player.moveToLane(player.lane - 1);
  }

  void moveRight() {
    if (_runIsActive) player.moveToLane(player.lane + 1);
  }

  Future<void> restart() async {
    overlays.remove(GameOverOverlay.overlayId);
    overlays.remove(WinnerOverlay.overlayId);
    for (final obstacle in children.whereType<Obstacle>().toList()) {
      obstacle.removeFromParent();
    }

    _distance = 0;
    _elapsed = 0;
    _spawnTimer = 0.45;
    _scoreModifier = 0;
    obstacleSpeed = 250;
    stars.value = 0;
    isGameOver.value = false;
    _runIsActive = true;

    // Сброс кулдаунов бонусов
    _eggJuniorCooldown = 4.0; // Сброс на 4 секунды при перезапуске
    _eggMiddleCooldown = 20.0 + _random.nextDouble() * 5.0;
    _eggSuperCooldown = 30.0 + _random.nextDouble() * 10.0;

    player
      ..lane = lanes.laneCount ~/ 2
      ..applyLayout();
  }

  Future<void> endRun() async {
    if (!_runIsActive) return;

    _runIsActive = false;
    isGameOver.value = true;
    unawaited(GameAudioController.instance.playCrashVibration());

    if (await ProgressStorage.instance.saveBestScoreIfHigher(stars.value)) {
      overlays.add(WinnerOverlay.overlayId);
    } else {
      overlays.add(GameOverOverlay.overlayId);
    }
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

  double _nextSpawnDelay() {
    final maxDelay = math.max(0.38, 1.05 - (_elapsed * 0.012));
    final minDelay = math.max(0.2, 0.55 - (_elapsed * 0.006));
    return minDelay + (_random.nextDouble() * (maxDelay - minDelay));
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
    canvas.drawRect(rect, _roadPaint);

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

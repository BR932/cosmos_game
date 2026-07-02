import 'dart:math' as math;

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'game.dart';

class PlayerCar extends SpriteComponent
    with CollisionCallbacks, HasGameReference<CyberRunnerGame> {
  PlayerCar({
    required Sprite sprite,
    required this.lane,
    required Vector2 position,
    required Vector2 size,
  }) : super(
         sprite: sprite,
         position: position,
         size: size,
         anchor: Anchor.center,
         priority: 20,
       );

  int lane;
  double _targetX = 0;

  late final RectangleHitbox _hitbox;

  static const double _hitboxWidthRatio = 0.80;
  static const double _hitboxHeightRatio = 0.70;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _targetX = position.x;

    _hitbox = RectangleHitbox.relative(
      Vector2(_hitboxWidthRatio, _hitboxHeightRatio),
      parentSize: size,
      anchor: Anchor.center,
    )..collisionType = CollisionType.active;

    add(_hitbox);
  }

  @override
  void update(double dt) {
    super.update(dt);
    final smoothing = 1 - math.pow(0.001, dt).toDouble();
    position.x += (_targetX - position.x) * smoothing;
  }

  void moveToLane(int nextLane) {
    lane = game.lanes.clampLane(nextLane);
    _targetX = game.lanes.laneCenterX(lane);
  }

  void applyLayout() {
    size = game.playerSize;

    if (isLoaded) {
      _syncHitboxLayout();
    }

    position.y = game.lanes.playerStartPosition(lane).y;
    _targetX = game.lanes.laneCenterX(lane);
    position.x = _targetX;
  }

  void _syncHitboxLayout() {
    _hitbox
      ..size = Vector2(size.x * _hitboxWidthRatio, size.y * _hitboxHeightRatio)
      ..position = size / 2;
  }
}

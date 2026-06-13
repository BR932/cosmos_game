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

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _targetX = position.x;
    add(
      RectangleHitbox.relative(
        Vector2(0.55, 0.72),
        parentSize: size,
        anchor: Anchor.center,
      )..collisionType = CollisionType.active,
    );
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
    position.y = game.lanes.playerStartPosition(lane).y;
    _targetX = game.lanes.laneCenterX(lane);
    position.x = _targetX;
  }
}

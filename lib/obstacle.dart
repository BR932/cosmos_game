import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'game.dart';
import 'player_car.dart';

class Obstacle extends SpriteComponent
    with CollisionCallbacks, HasGameReference<CyberRunnerGame> {
  Obstacle({
    required Sprite sprite,
    required this.lane,
    required Vector2 position,
    required Vector2 size,
  }) : super(
         sprite: sprite,
         position: position,
         size: size,
         anchor: Anchor.center,
         priority: 12,
       );

  final int lane;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    add(
      RectangleHitbox.relative(
        Vector2(0.62, 0.66),
        parentSize: size,
        anchor: Anchor.center,
      )..collisionType = CollisionType.passive,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.y += game.obstacleSpeed * dt;

    if (position.y - size.y > game.size.y + 40) {
      removeFromParent();
    }
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is PlayerCar) {
      game.endRun();
    }
  }

  void applyLayout() {
    size = game.obstacleSize;
    position.x = game.lanes.laneCenterX(lane);
  }
}

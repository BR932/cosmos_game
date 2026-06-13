import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/widgets.dart';

class LaneManager {
  LaneManager({this.laneCount = 5});

  final int laneCount;

  late Rect roadRect;
  late double laneWidth;

  void resize(Vector2 gameSize) {
    // The road stays centered and leaves room for the HUD and touch controls.
    final horizontalInset = math.max(18.0, gameSize.x * 0.08);
    final topInset = math.max(64.0, gameSize.y * 0.08);
    final bottomInset = math.max(108.0, gameSize.y * 0.14);
    final roadWidth = gameSize.x - (horizontalInset * 2);

    roadRect = Rect.fromLTWH(
      horizontalInset,
      topInset,
      roadWidth,
      math.max(1, gameSize.y - topInset - bottomInset),
    );
    laneWidth = roadRect.width / laneCount;
  }

  double laneCenterX(int lane) {
    return roadRect.left + (laneWidth * (lane + 0.5));
  }

  Vector2 playerStartPosition(int lane) {
    return Vector2(laneCenterX(lane), roadRect.bottom - laneWidth * 1.05);
  }

  double normalizedCarWidth() {
    return math.min(laneWidth * 0.58, 76);
  }

  double normalizedObstacleWidth() {
    return math.min(laneWidth * 0.68, 86);
  }

  int clampLane(int lane) {
    return lane.clamp(0, laneCount - 1);
  }
}

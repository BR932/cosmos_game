import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'game.dart'; // Путь к вашему файлу CyberRunnerGame
import 'player_car.dart'; // Путь к вашему файлу PlayerCar

class Obstacle extends SpriteComponent
    with CollisionCallbacks, HasGameReference<CyberRunnerGame> {
  // Номер дорожки, на которой находится объект
  final int lane;

  // Количество очков. Если положительное (20, 45, 85) — это яйцо-бонус.
  // Если отрицательное (-10, -15, -20, -35) — это препятствие.
  final int scoreChange;

  // Если true — столкновение сразу завершает игру. Любой отрицательный scoreChange тоже завершает забег.
  final bool endsRunOnCollision;

  Obstacle({
    required Sprite sprite,
    required this.lane,
    required Vector2 position,
    required Vector2 size,
    required this.scoreChange,
    this.endsRunOnCollision = false,
  }) : super(
         sprite: sprite,
         position: position,
         size: size,
         anchor: Anchor.center, // Центрируем объект для плавного выравнивания
       );

  // Переопределяем геттер priority. Flame запрашивает его напрямую при отрисовке.
  // Теперь препятствия (scoreChange <= 0) ВСЕГДА имеют приоритет 20,
  // а яйца (scoreChange > 0) имеют приоритет 10. Препятствия будут строго ПОВЕРХ яиц.
  @override
  int get priority => scoreChange > 0 ? 25 : 20;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Добавляем хитбокс (зону столкновения).
    // Делаем его чуть меньше физического размера картинки (85%),
    // чтобы игроку было комфортнее уворачиваться, и не было "ложных" аварий по краям текстуры.
    add(
      RectangleHitbox(
        size: size * 0.85,
        anchor: Anchor.center,
        position: size / 2,
        collisionType: CollisionType
            .passive, // Пассивный тип, так как объект просто движется по рельсам
      ),
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Двигаем объект вниз по экрану со скоростью, которая растет со временем в игре
    position.y += game.obstacleSpeed * dt;

    // Оптимизация памяти: если объект полностью ушел за нижнюю границу экрана,
    // мы удаляем его из игры, чтобы он не тратил ресурсы смартфона
    if (position.y > game.size.y + size.y) {
      removeFromParent();
    }
  }

  // Этот метод вызывается автоматически движком при изменении размеров экрана (например, поворот устройства)
  void applyLayout() {
    size = game.obstacleSize;
    position.x = game.lanes.laneCenterX(lane);
  }

  // Обработка столкновения
  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    // Проверяем, врезался ли объект именно в машину игрока
    if (other is PlayerCar) {
      // Вызываем метод изменения очков в главном классе игры.
      // Если врезались в препятствие -> передастся минус и игра может закончиться (Game Over).
      // Если поймали яйцо -> передастся плюс и очки увеличатся.
      game.modifyScore(scoreChange);

      if (endsRunOnCollision || scoreChange < 0) {
        game.endRun();
      }

      // Сразу убираем объект с экрана, чтобы столкновение не засчиталось повторно в следующем кадре
      removeFromParent();
    }
  }
}

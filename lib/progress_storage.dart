import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists player progress and achievements locally on the device.
class ProgressStorage {
  ProgressStorage._();

  static final ProgressStorage instance = ProgressStorage._();

  static const String bestScoreKey = 'best_stars';

  SharedPreferences? _preferences;
  final ValueNotifier<int> bestStars = ValueNotifier<int>(0);

  Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
    bestStars.value = _preferences?.getInt(bestScoreKey) ?? 0;
  }

  int get bestScore => bestStars.value;

  Future<bool> saveBestScoreIfHigher(int score) async {
    _preferences ??= await SharedPreferences.getInstance();

    if (score <= bestStars.value) {
      return false;
    }

    bestStars.value = score;
    await _preferences!.setInt(bestScoreKey, score);
    return true;
  }
}

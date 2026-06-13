import 'package:flutter/material.dart';

import '../game.dart';

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({required this.game, super.key});

  static const String overlayId = 'game_over';

  final CyberRunnerGame game;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xAA050713),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xF00A1026),
                border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Color(0xAA00E5FF), blurRadius: 28),
                  BoxShadow(color: Color(0x66FF2BD6), blurRadius: 40),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text(
                      'GAME OVER',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFF2BD6),
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 22),
                    _ScoreLine(label: 'Current score', value: game.stars.value),
                    const SizedBox(height: 8),
                    _ScoreLine(
                      label: 'Best score',
                      value: game.bestStars.value,
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: game.restart,
                        icon: const Icon(Icons.restart_alt_rounded),
                        label: const Text('Restart'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF00E5FF),
                          foregroundColor: const Color(0xFF04111F),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreLine extends StatelessWidget {
  const _ScoreLine({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFBDEFFF),
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        Text(
          '$value',
          style: const TextStyle(
            color: Color(0xFFFFF176),
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

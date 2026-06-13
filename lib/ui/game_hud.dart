import 'package:flutter/material.dart';

import '../game.dart';

class GameHud extends StatelessWidget {
  const GameHud({required this.game, super.key});

  static const String overlayId = 'game_hud';

  final CyberRunnerGame game;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        Positioned(
          top: MediaQuery.paddingOf(context).top + 14,
          left: 18,
          right: 18,
          child: _ScoreBar(game: game),
        ),
        Positioned(
          left: 22,
          bottom: MediaQuery.paddingOf(context).bottom + 22,
          child: _LaneButton(
            icon: Icons.chevron_left_rounded,
            onPressed: game.moveLeft,
          ),
        ),
        Positioned(
          right: 22,
          bottom: MediaQuery.paddingOf(context).bottom + 22,
          child: _LaneButton(
            icon: Icons.chevron_right_rounded,
            onPressed: game.moveRight,
          ),
        ),
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.game});

  final CyberRunnerGame game;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        _HudPill(
          label: 'STARS',
          listenable: game.stars,
          icon: Icons.star_rounded,
        ),
        _HudPill(
          label: 'BEST',
          listenable: game.bestStars,
          icon: Icons.bolt_rounded,
        ),
      ],
    );
  }
}

class _HudPill extends StatelessWidget {
  const _HudPill({
    required this.label,
    required this.listenable,
    required this.icon,
  });

  final String label;
  final ValueNotifier<int> listenable;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: listenable,
      builder: (context, _) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xCC081025),
            border: Border.all(color: const Color(0xAA00E5FF), width: 1.4),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x6600E5FF),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, color: const Color(0xFFFFF176), size: 20),
                const SizedBox(width: 8),
                Text(
                  '$label ${listenable.value}',
                  style: const TextStyle(
                    color: Color(0xFFEAFBFF),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LaneButton extends StatelessWidget {
  const _LaneButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 74,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xDD081025),
          border: Border.all(color: const Color(0xFFFF2BD6), width: 1.5),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x88FF2BD6),
              blurRadius: 22,
              spreadRadius: 1,
            ),
          ],
        ),
        child: IconButton(
          tooltip: icon == Icons.chevron_left_rounded
              ? 'Move left'
              : 'Move right',
          onPressed: onPressed,
          icon: Icon(icon, size: 46, color: const Color(0xFFEAFBFF)),
        ),
      ),
    );
  }
}

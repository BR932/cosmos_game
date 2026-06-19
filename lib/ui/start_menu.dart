import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:space_chicken/ui/settings_page.dart';

import '../audio/game_audio_controller.dart';

class StartMenu extends StatefulWidget {
  const StartMenu({required this.onStart, super.key});

  final Future<void> Function() onStart;

  @override
  State<StartMenu> createState() => _StartMenuState();
}

class _StartMenuState extends State<StartMenu> {
  // Переменные состояния настроек теперь хранятся на уровне приложения/контроллера
  // или передаются в экран настроек. Для синхронизации данных при возврате
  // мы просто вызываем setState, чтобы обновить интерфейс главного меню, если это необходимо.

  Future<void> _openSettings() async {
    await GameAudioController.instance.playTransitionSound();
    if (!mounted) return;

    // Мгновенный переход на отдельный экран без анимации
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => const SettingsScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );

    // Обновляем состояние главного меню после возврата с экрана настроек
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/Background_start_menu.png',
            fit: BoxFit.cover,
          ),
          const CustomPaint(painter: _StarFieldPainter()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/images/Logo_master.png',
                width: double.infinity,
                fit: BoxFit.fitWidth,
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              await GameAudioController.instance.playButtonSound();
                              await widget.onStart();
                            },
                            child: Image.asset(
                              'assets/images/Cutout 1.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              GestureDetector(
                                onTap: _openSettings,
                                child: Image.asset(
                                  'assets/images/settings.png',
                                  fit: BoxFit.contain,
                                  width: 80,
                                  height: 80,
                                ),
                              ),
                              const SizedBox(width: 16),
                              GestureDetector(
                                onTap: () async {
                                  await GameAudioController.instance.playButtonSound();
                                  await SystemNavigator.pop();
                                },
                                child: Image.asset(
                                  'assets/images/logout.png',
                                  fit: BoxFit.contain,
                                  width: 80,
                                  height: 80,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- ОТДЕЛЬНАЯ СТРАН

class _SettingsSwitch extends StatelessWidget {
  const _SettingsSwitch({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      secondary: Icon(icon, color: const Color(0xFF00E5FF)),
      title: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFEAFBFF),
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      value: value,
      activeThumbColor: const Color(0xFFFFF176),
      activeTrackColor: const Color(0x9900E5FF),
      inactiveThumbColor: const Color(0xFFBDEFFF),
      inactiveTrackColor: const Color(0x66071024),
      onChanged: onChanged,
    );
  }
}

class _StarFieldPainter extends CustomPainter {
  const _StarFieldPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final starPaint = Paint()..color = const Color(0x99BDEFFF);
    final glowPaint = Paint()
      ..color = const Color(0x2200E5FF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 36);

    canvas.drawCircle(Offset(size.width * 0.24, size.height * 0.18), 74, glowPaint);
    canvas.drawCircle(Offset(size.width * 0.78, size.height * 0.72), 96, glowPaint);

    for (var i = 0; i < 72; i++) {
      final x = ((i * 67) % math.max(size.width.toInt(), 1)).toDouble();
      final y = ((i * 131) % math.max(size.height.toInt(), 1)).toDouble();
      final radius = i % 5 == 0 ? 1.7 : 0.9;
      canvas.drawCircle(Offset(x, y), radius, starPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
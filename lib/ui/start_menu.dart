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
  Future<void> _openSettings() async {
    await GameAudioController.instance.playTransitionSound();
    if (!mounted) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const SettingsScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, viewport) {
          final isViewportLandscape = viewport.maxWidth > viewport.maxHeight;

          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/Background_start_menu.jpg',
                fit: BoxFit.cover,
              ),
              const CustomPaint(painter: _StarFieldPainter()),
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    0,
                    24,
                    isViewportLandscape
                        ? _adaptiveBottomPadding(viewport.maxHeight)
                        : 0,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isLandscape =
                          constraints.maxWidth > constraints.maxHeight;
                      final contentMaxWidth = math.min(
                        480.0,
                        constraints.maxWidth * 0.88,
                      );
                      final controlsHeight = _controlsHeight(
                        constraints.maxHeight,
                        isLandscape,
                      );
                      final gap = _adaptiveGap(constraints.maxHeight);
                      final iconSize = _iconSize(
                        contentMaxWidth,
                        controlsHeight,
                        isLandscape,
                      );

                      if (!isLandscape) {
                        return _buildPortraitMenu(
                          constraints: constraints,
                          contentMaxWidth: contentMaxWidth,
                          iconSize: iconSize,
                          gap: gap,
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Center(
                              child: SizedBox.expand(
                                child: Image.asset(
                                  'assets/images/Logo_master.png',
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: controlsHeight,
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: contentMaxWidth,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: Center(
                                        child: GestureDetector(
                                          onTap: () async {
                                            await GameAudioController.instance
                                                .playButtonSound();
                                            await widget.onStart();
                                          },
                                          child: Image.asset(
                                            'assets/images/Cutout 1.png',
                                            width: contentMaxWidth,
                                            fit: BoxFit.contain,
                                            alignment: Alignment.center,
                                            filterQuality: FilterQuality.medium,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: gap),
                                    SizedBox(
                                      height: iconSize,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          _MenuIconButton(
                                            asset: 'assets/images/settings.png',
                                            size: iconSize,
                                            onTap: _openSettings,
                                          ),
                                          SizedBox(width: iconSize * 0.16),
                                          _MenuIconButton(
                                            asset: 'assets/images/logout.png',
                                            size: iconSize,
                                            onTap: () async {
                                              await GameAudioController.instance
                                                  .playButtonSound();
                                              await SystemNavigator.pop();
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPortraitMenu({
    required BoxConstraints constraints,
    required double contentMaxWidth,
    required double iconSize,
    required double gap,
  }) {
    final logoSize = math.min(contentMaxWidth, constraints.maxHeight * 0.46);

    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: contentMaxWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/Logo_master.png',
                width: logoSize,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                filterQuality: FilterQuality.medium,
              ),
              SizedBox(height: gap),
              GestureDetector(
                onTap: () async {
                  await GameAudioController.instance.playButtonSound();
                  await widget.onStart();
                },
                child: Image.asset(
                  'assets/images/Cutout 1.png',
                  width: contentMaxWidth,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              SizedBox(height: gap),
              SizedBox(
                height: iconSize,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _MenuIconButton(
                      asset: 'assets/images/settings.png',
                      size: iconSize,
                      onTap: _openSettings,
                    ),
                    SizedBox(width: iconSize * 0.16),
                    _MenuIconButton(
                      asset: 'assets/images/logout.png',
                      size: iconSize,
                      onTap: () async {
                        await GameAudioController.instance.playButtonSound();
                        await SystemNavigator.pop();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _adaptiveBottomPadding(double height) {
    return math.min(40.0, math.max(10.0, height * 0.055));
  }

  double _adaptiveGap(double height) {
    return math.min(16.0, math.max(6.0, height * 0.018));
  }

  double _controlsHeight(double height, bool isLandscape) {
    final target = height * (isLandscape ? 0.46 : 0.38);
    final maxHeight = height * (isLandscape ? 0.62 : 0.48);
    return math.min(math.max(118.0, target), maxHeight);
  }

  double _iconSize(
    double contentMaxWidth,
    double controlsHeight,
    bool isLandscape,
  ) {
    final widthBased = contentMaxWidth * (isLandscape ? 0.18 : 0.22);
    final heightBased = controlsHeight * (isLandscape ? 0.34 : 0.36);
    return math.min(math.max(44.0, widthBased), heightBased);
  }
}

class _MenuIconButton extends StatelessWidget {
  const _MenuIconButton({
    required this.asset,
    required this.size,
    required this.onTap,
  });

  final String asset;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox.square(
        dimension: size,
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
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

    canvas.drawCircle(
      Offset(size.width * 0.24, size.height * 0.18),
      74,
      glowPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.78, size.height * 0.72),
      96,
      glowPaint,
    );

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

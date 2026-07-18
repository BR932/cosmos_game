import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../audio/game_audio_controller.dart';
import '../system_ui_config.dart';

class BonusNotificationScreen extends StatefulWidget {
  const BonusNotificationScreen({
    super.key,
    required this.onBonusPressed,
    required this.onDismiss,
  });

  final VoidCallback onBonusPressed;
  final VoidCallback onDismiss;

  @override
  State<BonusNotificationScreen> createState() =>
      _BonusNotificationScreenState();
}

class _BonusNotificationScreenState extends State<BonusNotificationScreen> {
  static const Color _background = Color(0xFF050713);

  @override
  void initState() {
    super.initState();
    allowFreeRotation();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: _background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            isLandscape
                ? 'assets/images/BGforNotifications_gorezantal.jpg'
                : 'assets/images/BGforNotifications.jpg',
            fit: BoxFit.cover,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x00050713),
                  Color(0x33050713),
                  Color(0xDD050713),
                ],
                stops: [0.45, 0.72, 1],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final layout = _BonusPromptLayout.from(
                  constraints,
                  isLandscape: isLandscape,
                );

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    layout.horizontalPadding,
                    layout.topPadding,
                    layout.horizontalPadding,
                    layout.bottomPadding,
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: layout.contentMaxWidth,
                        maxHeight: layout.contentMaxHeight,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          width: layout.contentMaxWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _PromptImage(
                                imagePath: isLandscape
                                    ? 'assets/images/Allow notifications about bonuses and promos_2.png'
                                    : 'assets/images/Allow notifications about bonuses and promos.png',
                                height: layout.titleHeight,
                              ),
                              SizedBox(height: layout.titleGap),
                              _PromptImage(
                                imagePath: isLandscape
                                    ? 'assets/images/Stay tuned with best offers from our casino_2.png'
                                    : 'assets/images/Stay tuned with best offers from our casino.png',
                                height: layout.subtitleHeight,
                              ),
                              SizedBox(height: layout.copyGap),
                              SizedBox(
                                width: layout.copyMaxWidth,
                                child: Text(
                                  'This app uses notifications to deliver bonuses and promos. You can change this later in system settings.',
                                  textAlign: TextAlign.center,
                                  maxLines: isLandscape ? 2 : 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.moul(
                                    color: Colors.white70,
                                    fontSize: layout.copyFontSize,
                                    height: 1.18,
                                  ),
                                ),
                              ),
                              SizedBox(height: layout.buttonGap),
                              _BonusButton(
                                onPressed: () async {
                                  await GameAudioController.instance
                                      .playButtonSound();
                                  widget.onBonusPressed();
                                },
                                width: layout.buttonWidth,
                                height: layout.buttonHeight,
                                imagePath: isLandscape
                                    ? 'assets/images/Rectangle 4076_2.png'
                                    : 'assets/images/Rectangle 4077.png',
                              ),
                              SizedBox(height: layout.skipGap),
                              TextButton(
                                onPressed: () async {
                                  await GameAudioController.instance
                                      .playButtonSound();
                                  widget.onDismiss();
                                },
                                style: TextButton.styleFrom(
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: layout.skipHorizontalPadding,
                                    vertical: layout.skipVerticalPadding,
                                  ),
                                ),
                                child: Text(
                                  'Skip',
                                  style: GoogleFonts.moul(
                                    color: Colors.white70,
                                    fontSize: layout.skipFontSize,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BonusPromptLayout {
  const _BonusPromptLayout({
    required this.horizontalPadding,
    required this.topPadding,
    required this.bottomPadding,
    required this.contentMaxWidth,
    required this.contentMaxHeight,
    required this.titleHeight,
    required this.subtitleHeight,
    required this.copyMaxWidth,
    required this.copyFontSize,
    required this.buttonWidth,
    required this.buttonHeight,
    required this.skipFontSize,
    required this.titleGap,
    required this.copyGap,
    required this.buttonGap,
    required this.skipGap,
    required this.skipHorizontalPadding,
    required this.skipVerticalPadding,
  });

  final double horizontalPadding;
  final double topPadding;
  final double bottomPadding;
  final double contentMaxWidth;
  final double contentMaxHeight;
  final double titleHeight;
  final double subtitleHeight;
  final double copyMaxWidth;
  final double copyFontSize;
  final double buttonWidth;
  final double buttonHeight;
  final double skipFontSize;
  final double titleGap;
  final double copyGap;
  final double buttonGap;
  final double skipGap;
  final double skipHorizontalPadding;
  final double skipVerticalPadding;

  factory _BonusPromptLayout.from(
    BoxConstraints constraints, {
    required bool isLandscape,
  }) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final shortest = width < height ? width : height;

    if (isLandscape) {
      final contentWidth = (width * 0.62).clamp(420.0, 760.0).toDouble();
      final buttonWidth = (width * 0.44).clamp(360.0, 620.0).toDouble();
      return _BonusPromptLayout(
        horizontalPadding: (width * 0.06).clamp(20.0, 56.0).toDouble(),
        topPadding: 10,
        bottomPadding: (height * 0.05).clamp(8.0, 22.0).toDouble(),
        contentMaxWidth: contentWidth,
        contentMaxHeight: height * 0.58,
        titleHeight: (height * 0.075).clamp(14.0, 26.0).toDouble(),
        subtitleHeight: (height * 0.07).clamp(14.0, 24.0).toDouble(),
        copyMaxWidth: contentWidth * 0.82,
        copyFontSize: (height * 0.033).clamp(10.0, 14.0).toDouble(),
        buttonWidth: buttonWidth,
        buttonHeight: buttonWidth / (2205 / 156),
        skipFontSize: (height * 0.06).clamp(16.0, 24.0).toDouble(),
        titleGap: (height * 0.025).clamp(6.0, 12.0).toDouble(),
        copyGap: (height * 0.025).clamp(6.0, 12.0).toDouble(),
        buttonGap: (height * 0.035).clamp(8.0, 16.0).toDouble(),
        skipGap: (height * 0.02).clamp(5.0, 10.0).toDouble(),
        skipHorizontalPadding: 16,
        skipVerticalPadding: 4,
      );
    }

    final contentWidth = (width * 0.88).clamp(280.0, 460.0).toDouble();
    final buttonWidth = (width * 0.76).clamp(248.0, 340.0).toDouble();
    return _BonusPromptLayout(
      horizontalPadding: (shortest * 0.06).clamp(18.0, 28.0).toDouble(),
      topPadding: 12,
      bottomPadding: (height * 0.045).clamp(18.0, 34.0).toDouble(),
      contentMaxWidth: contentWidth,
      contentMaxHeight: height * 0.48,
      titleHeight: (height * 0.045).clamp(28.0, 42.0).toDouble(),
      subtitleHeight: (height * 0.032).clamp(19.0, 28.0).toDouble(),
      copyMaxWidth: contentWidth * 0.92,
      copyFontSize: (shortest * 0.034).clamp(11.0, 14.0).toDouble(),
      buttonWidth: buttonWidth,
      buttonHeight: buttonWidth / (934 / 157),
      skipFontSize: (shortest * 0.062).clamp(20.0, 26.0).toDouble(),
      titleGap: (height * 0.018).clamp(10.0, 18.0).toDouble(),
      copyGap: (height * 0.014).clamp(8.0, 12.0).toDouble(),
      buttonGap: (height * 0.026).clamp(14.0, 22.0).toDouble(),
      skipGap: (height * 0.016).clamp(8.0, 14.0).toDouble(),
      skipHorizontalPadding: 18,
      skipVerticalPadding: 6,
    );
  }
}

class _PromptImage extends StatelessWidget {
  const _PromptImage({required this.imagePath, required this.height});

  final String imagePath;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Image.asset(imagePath, fit: BoxFit.contain),
    );
  }
}

class _BonusButton extends StatelessWidget {
  const _BonusButton({
    required this.onPressed,
    required this.width,
    required this.height,
    required this.imagePath,
  });

  final VoidCallback onPressed;
  final double width;
  final double height;
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          width: width,
          height: height,
          child: Image.asset(imagePath, fit: BoxFit.fill),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../audio/game_audio_controller.dart';
import '../config/app_attribution_config.dart';
import '../external_link_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  static const String privacyPolicyUrl =
      '${AppAttributionConfig.siteUrl}/privacy-policy.html';
  static const String supportUrl =
      '${AppAttributionConfig.siteUrl}/support.html';

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _musicEnabled = true;
  bool _soundEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final audio = GameAudioController.instance;
    await audio.init();
    if (!mounted) return;

    setState(() {
      _musicEnabled = audio.musicEnabled;
      _soundEnabled = audio.soundEnabled;
      _isLoading = false;
    });
  }

  Future<void> _toggleMusic() async {
    await GameAudioController.instance.playButtonSound();
    setState(() {
      _musicEnabled = !_musicEnabled;
    });
    await GameAudioController.instance.setMusicEnabled(_musicEnabled);
  }

  Future<void> _toggleSound() async {
    await GameAudioController.instance.playButtonSound();
    setState(() {
      _soundEnabled = !_soundEnabled;
    });
    await GameAudioController.instance.setSoundEnabled(_soundEnabled);
  }

  Future<void> _openExternalLink(String url) async {
    await GameAudioController.instance.playButtonSound();
    if (!mounted) return;

    final opened = await ExternalLinkLauncher.open(url);

    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open link: $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/Background_settings.png',
            fit: BoxFit.cover,
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
              ),
            )
          else
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isLandscape =
                      constraints.maxWidth > constraints.maxHeight;
                  final horizontalPadding = isLandscape
                      ? (constraints.maxWidth < 380 ? 12.0 : 24.0)
                      : 24.0;
                  final verticalPadding = isLandscape
                      ? (constraints.maxHeight < 520 ? 8.0 : 20.0)
                      : 20.0;
                  final sceneHeight = isLandscape ? 548.0 : 537.0;
                  final titleWidth = isLandscape ? 340.0 : 360.0;
                  final panelTop = isLandscape ? 104.0 : 110.0;

                  return Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: 360,
                          height: sceneHeight,
                          child: Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              Positioned(
                                top: 0,
                                child: Image.asset(
                                  'assets/images/settings_text.png',
                                  width: titleWidth,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.medium,
                                ),
                              ),
                              Positioned(
                                top: panelTop,
                                child: _SettingsPanel(
                                  compact: isLandscape,
                                  musicEnabled: _musicEnabled,
                                  soundEnabled: _soundEnabled,
                                  onMusicTap: _toggleMusic,
                                  onSoundTap: _toggleSound,
                                  onPrivacyTap: () => _openExternalLink(
                                    SettingsScreen.privacyPolicyUrl,
                                  ),
                                  onSupportTap: () => _openExternalLink(
                                    SettingsScreen.supportUrl,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                child: _SettingsImageButton(
                                  width: 220,
                                  asset: 'assets/images/button_back.png',
                                  onTap: () async {
                                    await GameAudioController.instance
                                        .playButtonSound();
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ),
                            ],
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

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.compact,
    required this.musicEnabled,
    required this.soundEnabled,
    required this.onMusicTap,
    required this.onSoundTap,
    required this.onPrivacyTap,
    required this.onSupportTap,
  });

  final bool compact;
  final bool musicEnabled;
  final bool soundEnabled;
  final VoidCallback onMusicTap;
  final VoidCallback onSoundTap;
  final VoidCallback onPrivacyTap;
  final VoidCallback onSupportTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: compact ? 338 : 340,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/settings_contaner.png'),
          fit: BoxFit.fill,
        ),
      ),
      padding: EdgeInsets.fromLTRB(28, 55, 28, compact ? 15 : 12),
      child: Column(
        children: [
          _SettingsToggleRow(
            compact: compact,
            labelAsset: 'assets/images/Music.png',
            enabled: musicEnabled,
            onTap: onMusicTap,
          ),
          _SettingsToggleRow(
            compact: compact,
            labelAsset: 'assets/images/Sound.png',
            enabled: soundEnabled,
            onTap: onSoundTap,
          ),
          SizedBox(height: compact ? 12 : 20),
          _SettingsImageButton(
            width: compact ? 170 : 180,
            asset: 'assets/images/Privacy Policy.png',
            onTap: onPrivacyTap,
          ),
          _SettingsImageButton(
            width: compact ? 170 : 180,
            asset: 'assets/images/Support.png',
            onTap: onSupportTap,
          ),
        ],
      ),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.compact,
    required this.labelAsset,
    required this.enabled,
    required this.onTap,
  });

  final bool compact;
  final String labelAsset;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: compact ? 50 : 54,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Image.asset(
            labelAsset,
            height: 20,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
          _SettingsImageButton(
            width: 85,
            asset: enabled
                ? 'assets/images/btton_on.png'
                : 'assets/images/button_off.png',
            onTap: onTap,
          ),
        ],
      ),
    );
  }
}

class _SettingsImageButton extends StatelessWidget {
  const _SettingsImageButton({
    required this.width,
    required this.asset,
    required this.onTap,
  });

  final double width;
  final String asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Image.asset(
        asset,
        width: width,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

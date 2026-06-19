import 'package:flutter/material.dart';
import '../audio/game_audio_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                     
                      Stack(
                        alignment: Alignment.topCenter,
                        clipBehavior: Clip.none,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              top: 60,
                            ),child: Container(
                              width:
                                  280,
                              height:
                                  340,
                              decoration: const BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage(
                                    'assets/images/settings_contaner.png',
                                  ),
                                  fit: BoxFit.fill,
                                ),
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                28,
                                55,
                                28,
                                20,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment
                                    .spaceBetween,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      Image.asset(
                                        'assets/images/Music.png',
                                        height: 20,
                                        fit: BoxFit.contain,
                                      ),
                                      GestureDetector(
                                        onTap: _toggleMusic,
                                        child: Image.asset(
                                          _musicEnabled
                                              ? 'assets/images/btton_on.png'
                                              : 'assets/images/button_off.png',
                                          height: 45,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      Image.asset(
                                        'assets/images/Sound.png',
                                        height: 20,
                                        fit: BoxFit.contain,
                                      ),
                                      GestureDetector(
                                        onTap: _toggleSound,
                                        child: Image.asset(
                                          _soundEnabled
                                              ? 'assets/images/btton_on.png'
                                              : 'assets/images/button_off.png',
                                          height: 45,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(
                                    height: 5,
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      await GameAudioController.instance
                                          .playButtonSound();
                                    },
                                    child: Image.asset(
                                      'assets/images/Privacy Policy.png',
                                      width: 180,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () async {
                                      await GameAudioController.instance
                                          .playButtonSound();
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Поддержка: support@space-chicken.game',
                                          ),
                                        ),
                                      );
                                    },
                                    child: Image.asset(
                                      'assets/images/Support.png',
                                      width: 180,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                  SizedBox(height: 10)
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            top: -50,
                            child: Image.asset(
                              'assets/images/settings_text.png',
                              width: 360,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

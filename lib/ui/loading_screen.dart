import 'package:flutter/material.dart';

import '../system_ui_config.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  static const Duration displayDuration = Duration(milliseconds: 2500);

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    // Rotate with the device even when the system auto-rotate lock is on.
    allowFreeRotation();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFF050713),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset('assets/images/Background 2.jpg', fit: BoxFit.cover),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 120.0 : 40.0,
                vertical: isLandscape ? 20.0 : 40.0,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Spacer(),
                  // Animated Loading Indicator
                  const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF00E5FF),
                      ),
                      strokeWidth: 4.0,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Loading image/text
                  SizedBox(
                    height: isLandscape ? 40 : 60,
                    child: Image.asset(
                      'assets/images/loading.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'This app collects device and app usage data to support push notifications, configuration, and analytics. Privacy policy is available in Settings.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color.fromARGB(43, 255, 255, 255),
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: isLandscape ? 10 : 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../system_ui_config.dart';

class OfflineScreen extends StatefulWidget {
  const OfflineScreen({required this.onBack, super.key});

  final Future<void> Function() onBack;

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  @override
  void initState() {
    super.initState();
    // Rotate with the device even when the system auto-rotate lock is on.
    allowFreeRotation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset('assets/images/Background 2.jpg', fit: BoxFit.cover),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: <Widget>[
                  const Spacer(flex: 20),
                  Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      Image.asset(
                        'assets/images/500_error.png',
                        width: 250,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: widget.onBack,
                    child: Image.asset(
                      'assets/images/back.png',
                      width: 170,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const Spacer(flex: 3),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

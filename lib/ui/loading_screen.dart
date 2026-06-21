import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  static const Duration displayDuration = Duration(milliseconds: 2500);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset('assets/images/Background 2.png', fit: BoxFit.cover),
          Padding(
            padding: const EdgeInsets.all(65.0),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Image.asset(
                'assets/images/loading.png',
                width: double.infinity,
                fit: BoxFit.fitWidth,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

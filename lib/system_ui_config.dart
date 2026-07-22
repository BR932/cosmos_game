import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const MethodChannel _systemUiChannel = MethodChannel('space_chicken/system_ui');

const List<DeviceOrientation> _allOrientations = <DeviceOrientation>[
  DeviceOrientation.portraitUp,
  DeviceOrientation.portraitDown,
  DeviceOrientation.landscapeLeft,
  DeviceOrientation.landscapeRight,
];

/// Lets the screen follow the device sensor in every orientation, even when
/// the user has locked auto-rotation in the system settings.
///
/// On Android this must go through the native channel: Flutter's
/// [SystemChrome.setPreferredOrientations] maps the four orientations to
/// `SCREEN_ORIENTATION_FULL_USER`, which obeys the system auto-rotate lock.
/// The native side uses `SCREEN_ORIENTATION_FULL_SENSOR` instead, which does
/// not. Other platforms fall back to [SystemChrome.setPreferredOrientations].
Future<void> allowFreeRotation() async {
  if (Platform.isAndroid) {
    try {
      await _systemUiChannel.invokeMethod<void>('setOrientationMode', {
        'mode': 'sensor',
      });
      return;
    } on MissingPluginException {
      // Fall back to the Flutter API below.
    }
  }
  await SystemChrome.setPreferredOrientations(_allOrientations);
}

/// Locks the screen to portrait (used by the WebView / "white part").
Future<void> lockPortraitOrientation() async {
  if (Platform.isAndroid) {
    try {
      await _systemUiChannel.invokeMethod<void>('setOrientationMode', {
        'mode': 'portrait',
      });
      return;
    } on MissingPluginException {
      // Fall back to the Flutter API below.
    }
  }
  await SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
}

Future<void> configureImmersiveSystemUi() async {
  await _setDecorFitsSystemWindows(false);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );
}

Future<void> configureWebViewSystemUi() async {
  // Fullscreen WebView: draw edge-to-edge behind the (hidden) status and
  // navigation bars, exactly like the game. decorFitsSystemWindows(false) is
  // what SystemUiMode.immersiveSticky expects; forcing it back to true fights
  // the immersive layout and leaves the content inset by the system bars (the
  // "not fullscreen" bug). The display cutout is avoided in Flutter instead,
  // via SafeArea(top:) in ConfigWebViewScreen, which leaves only a black strip
  // under the camera. Keyboard insets keep flowing through MediaQuery.viewInsets
  // thanks to windowSoftInputMode="adjustResize".
  await _setDecorFitsSystemWindows(false);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
  );
}

Future<void> trimWebViewStorage({bool clearPersistentData = false}) async {
  try {
    await _systemUiChannel.invokeMethod<void>('trimWebViewStorage', {
      'clearPersistentData': clearPersistentData,
    });
  } on MissingPluginException {
    // iOS and platforms without the Android bridge rely on WebViewController cleanup.
  }
}

Future<void> _setDecorFitsSystemWindows(bool decorFits) async {
  try {
    await _systemUiChannel.invokeMethod<void>(
      'setDecorFitsSystemWindows',
      decorFits,
    );
  } on MissingPluginException {
    // iOS and platforms without the Android bridge rely on SystemChrome.
  }
}

/// Keeps status and navigation bars hidden; swipe from screen edge reveals them.
class ImmersiveSystemUiScope extends StatefulWidget {
  const ImmersiveSystemUiScope({required this.child, super.key});

  final Widget child;

  @override
  State<ImmersiveSystemUiScope> createState() => _ImmersiveSystemUiScopeState();
}

class _ImmersiveSystemUiScopeState extends State<ImmersiveSystemUiScope>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    configureImmersiveSystemUi();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      configureImmersiveSystemUi();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const MethodChannel _systemUiChannel = MethodChannel('space_chicken/system_ui');

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
  await _setDecorFitsSystemWindows(true);
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: SystemUiOverlay.values,
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.black,
      systemNavigationBarColor: Colors.black,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
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

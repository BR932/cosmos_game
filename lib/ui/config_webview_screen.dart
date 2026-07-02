import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../external_link_launcher.dart';
import '../system_ui_config.dart';

class ConfigWebViewScreen extends StatefulWidget {
  const ConfigWebViewScreen({
    super.key,
    required this.url,
    required this.onExit,
  });

  final String url;
  final VoidCallback onExit;

  @override
  State<ConfigWebViewScreen> createState() => _ConfigWebViewScreenState();
}

class _ConfigWebViewScreenState extends State<ConfigWebViewScreen>
    with WidgetsBindingObserver {
  WebViewController? _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    unawaited(configureWebViewSystemUi());

    _initWebView();
  }

  @override
  void dispose() {
    final controller = _controller;
    if (controller != null) {
      unawaited(_cleanupWebViewStorage(controller, clearLocalStorage: true));
    }
    unawaited(trimWebViewStorage(clearPersistentData: true));
    WidgetsBinding.instance.removeObserver(this);
    unawaited(configureImmersiveSystemUi());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(configureWebViewSystemUi());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      final controller = _controller;
      if (controller != null) {
        unawaited(_cleanupWebViewStorage(controller, clearLocalStorage: true));
      }
      unawaited(trimWebViewStorage(clearPersistentData: true));
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      unawaited(_syncKeyboardInsetWithWebView());
    });
  }

  Future<void> _initWebView() async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black);

    await _cleanupWebViewStorage(controller, clearLocalStorage: true);

    String? userAgent;

    if (Platform.isIOS) {
      userAgent =
          'Mozilla/5.0 (iPhone; CPU iPhone OS 18_1_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';
    } else if (Platform.isAndroid) {
      final rawUA = await ExternalLinkLauncher.getDefaultUserAgent();

      if (rawUA != null && rawUA.isNotEmpty) {
        userAgent = rawUA
            .replaceAll(RegExp(r';\s*wv'), '')
            .replaceAll(RegExp(r'Version/\d+\.\d+\s*'), '');
      }
    }

    if (userAgent != null) {
      await controller.setUserAgent(userAgent);
    }

    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (_) {
          if (!mounted) return;

          setState(() {
            _isLoading = true;
          });
        },
        onPageFinished: (_) async {
          if (!mounted) return;

          await _applyOfferLayoutFix(controller);
          await _syncKeyboardInsetWithWebView(controller);
          if (!mounted) return;

          unawaited(_cleanupWebViewStorage(controller));

          setState(() {
            _isLoading = false;
          });
        },
        onWebResourceError: (_) {
          if (!mounted) return;

          setState(() {
            _isLoading = false;
          });
        },
        onNavigationRequest: (request) {
          final uri = Uri.tryParse(request.url);

          if (uri == null) {
            return NavigationDecision.prevent;
          }

          final scheme = uri.scheme.toLowerCase();

          if (scheme != 'http' &&
              scheme != 'https' &&
              scheme != 'about' &&
              scheme != 'javascript') {
            _openExternal(uri);
            return NavigationDecision.prevent;
          }

          return NavigationDecision.navigate;
        },
      ),
    );

    if (Platform.isAndroid && controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;

      await androidController.setMediaPlaybackRequiresUserGesture(false);

      await androidController.setOnShowFileSelector(_androidFilePicker);

      await androidController.setOnPlatformPermissionRequest((request) {
        request.grant();
      });
    }

    await controller.loadRequest(Uri.parse(widget.url));

    if (!mounted) return;

    setState(() {
      _controller = controller;
    });
  }

  Future<void> _cleanupWebViewStorage(
    WebViewController controller, {
    bool clearLocalStorage = false,
  }) async {
    try {
      await controller.clearCache();
      if (clearLocalStorage) {
        await controller.clearLocalStorage();
      }
      await trimWebViewStorage(clearPersistentData: clearLocalStorage);
    } catch (error) {
      debugPrint('WEBVIEW STORAGE CLEANUP failed: $error');
    }
  }

  Future<void> _applyOfferLayoutFix(WebViewController controller) async {
    try {
      await controller.runJavaScript(r'''
        (function () {
          var root = document.documentElement;
          var viewport = document.querySelector('meta[name="viewport"]');
          if (!viewport) {
            viewport = document.createElement('meta');
            viewport.name = 'viewport';
            document.head.appendChild(viewport);
          }
          viewport.content = 'width=device-width, initial-scale=1, viewport-fit=cover';

          var style = document.getElementById('app-webview-landscape-form-fix');
          if (!style) {
            style = document.createElement('style');
            style.id = 'app-webview-landscape-form-fix';
            document.head.appendChild(style);
          }

          style.textContent = [
            ':root {',
            '  --app-keyboard-inset: 0px;',
            '  --app-visible-height: 100vh;',
            '}',
            '*, *::before, *::after {',
            '  box-sizing: border-box;',
            '}',
            'html, body {',
            '  width: 100%;',
            '  max-width: 100%;',
            '  min-height: var(--app-visible-height);',
            '  overflow-x: hidden !important;',
            '  -webkit-text-size-adjust: 100%;',
            '}',
            'body {',
            '  margin-left: auto;',
            '  margin-right: auto;',
            '}',
            'img, video, canvas, svg, iframe {',
            '  max-width: 100%;',
            '}',
            'table {',
            '  max-width: 100%;',
            '  display: block;',
            '  overflow-x: auto;',
            '}',
            'input, select, textarea, button {',
            '  box-sizing: border-box;',
            '  max-width: 100%;',
            '  scroll-margin-top: 24px;',
            '  scroll-margin-bottom: max(140px, calc(var(--app-keyboard-inset) + 24px));',
            '}',
            'body.app-webview-narrow input,',
            'body.app-webview-narrow select,',
            'body.app-webview-narrow textarea,',
            'body.app-webview-narrow button {',
            '  min-height: 44px;',
            '}',
            'body.app-webview-keyboard-open {',
            '  padding-bottom: max(160px, calc(var(--app-keyboard-inset) + 24px)) !important;',
            '}',
            'body.app-webview-landscape {',
            '  min-height: var(--app-visible-height) !important;',
            '  padding-bottom: max(32px, env(safe-area-inset-bottom)) !important;',
            '}',
            'html.app-webview-landscape-keyboard-open,',
            'html.app-webview-landscape-keyboard-open body {',
            '  height: var(--app-visible-height) !important;',
            '  max-height: var(--app-visible-height) !important;',
            '  overflow: hidden !important;',
            '}',
            'html.app-webview-landscape-keyboard-open body {',
            '  display: block !important;',
            '  overflow-x: hidden !important;',
            '  overflow-y: auto !important;',
            '  overscroll-behavior-y: contain;',
            '  -webkit-overflow-scrolling: touch;',
            '  padding-bottom: max(180px, calc(var(--app-keyboard-inset) + 32px)) !important;',
            '}',
            '@media (orientation: landscape) and (max-height: 620px) {',
            '  html, body {',
            '    height: auto !important;',
            '    min-height: var(--app-visible-height) !important;',
            '    overflow-y: auto !important;',
            '    overscroll-behavior-y: contain;',
            '    -webkit-overflow-scrolling: touch;',
            '  }',
            '  body.app-webview-keyboard-open {',
            '    min-height: calc(var(--app-visible-height) + var(--app-keyboard-inset)) !important;',
            '  }',
            '  form, [class*="form" i], [id*="form" i],',
            '  [class*="registration" i], [id*="registration" i],',
            '  [class*="signup" i], [id*="signup" i],',
            '  [class*="login" i], [id*="login" i],',
            '  [class*="content" i], [id*="content" i],',
            '  [class*="container" i], [id*="container" i],',
            '  [class*="wrapper" i], [id*="wrapper" i],',
            '  [class*="modal" i], [id*="modal" i],',
            '  main, [role="main"] {',
            '    max-height: none !important;',
            '    overflow: visible !important;',
            '  }',
            '  [style*="height: 100vh"],',
            '  [style*="height:100vh"],',
            '  [style*="min-height: 100vh"],',
            '  [style*="min-height:100vh"],',
            '  [style*="max-height: 100vh"],',
            '  [style*="max-height:100vh"] {',
            '    height: auto !important;',
            '    min-height: var(--app-visible-height) !important;',
            '    max-height: none !important;',
            '  }',
            '  html.app-webview-landscape-keyboard-open body > *,',
            '  html.app-webview-landscape-keyboard-open form,',
            '  html.app-webview-landscape-keyboard-open main,',
            '  html.app-webview-landscape-keyboard-open [role="main"] {',
            '    position: relative !important;',
            '    transform: none !important;',
            '  }',
            '}'
          ].join('\n');

          function focusedField() {
            var target = document.activeElement;
            if (!target || !target.matches || !target.matches('input, select, textarea')) {
              return null;
            }
            return target;
          }

          function keepFocusedFieldVisible(event) {
            var target = event && event.target ? event.target : focusedField();
            if (!target || !target.matches || !target.matches('input, select, textarea')) {
              return;
            }

            setTimeout(function () {
              try {
                target.scrollIntoView({
                  behavior: 'smooth',
                  block: 'nearest',
                  inline: 'nearest'
                });
              } catch (_) {
                target.scrollIntoView(false);
              }
            }, 120);
          }

          function onFieldFocus(event) {
            window.__appLastFocusedField = event.target;
            window.__appKeyboardRevealPending = true;
            keepFocusedFieldVisible(event);
          }

          function keepOfferFormVisible() {
            var target = focusedField() || document.querySelector(
              'form, input, select, textarea, [class*="form" i], [id*="form" i], [class*="registration" i], [id*="registration" i], [class*="signup" i], [id*="signup" i], [class*="login" i], [id*="login" i]'
            );
            if (!target || !target.scrollIntoView) {
              return;
            }

            setTimeout(function () {
              try {
                target.scrollIntoView({
                  behavior: 'smooth',
                  block: 'center',
                  inline: 'nearest'
                });
              } catch (_) {
                target.scrollIntoView(false);
              }
            }, 180);
          }

          function updateViewportState(forcedInset) {
            var visualViewport = window.visualViewport;
            var layoutHeight = Math.max(root.clientHeight || 0, window.innerHeight || 0);
            var visualHeight = visualViewport ? visualViewport.height : window.innerHeight;
            var visualOffsetTop = visualViewport ? visualViewport.offsetTop : 0;
            var measuredInset = Math.max(0, layoutHeight - visualHeight - visualOffsetTop);
            var flutterInset = Number(forcedInset || window.__appWebViewKeyboardInset || 0);
            var keyboardInset = Math.max(measuredInset, flutterInset);
            var keyboardOpen = keyboardInset > 80;
            var isLandscape = window.matchMedia('(orientation: landscape)').matches ||
              window.innerWidth > window.innerHeight;
            var isNarrow = Math.min(window.innerWidth, window.innerHeight) < 480;
            var previousKeyboardOpen = !!window.__appKeyboardWasOpen;
            var currentFocused = focusedField();

            if (currentFocused && currentFocused !== window.__appLastFocusedField) {
              window.__appLastFocusedField = currentFocused;
              window.__appKeyboardRevealPending = true;
            }

            root.style.setProperty('--app-keyboard-inset', Math.ceil(keyboardInset) + 'px');
            root.style.setProperty('--app-visible-height', Math.ceil(Math.max(1, visualHeight)) + 'px');
            root.classList.toggle('app-webview-landscape-keyboard-open', isLandscape && keyboardOpen);
            document.body.classList.toggle('app-webview-narrow', isNarrow);
            document.body.classList.toggle('app-webview-landscape', isLandscape);
            document.body.classList.toggle('app-webview-keyboard-open', keyboardOpen);

            if (keyboardOpen && (window.__appKeyboardRevealPending || !previousKeyboardOpen)) {
              keepFocusedFieldVisible({ target: currentFocused });
              setTimeout(function () {
                keepFocusedFieldVisible({ target: currentFocused });
              }, 260);
              window.__appKeyboardRevealPending = false;
            } else if (isLandscape) {
              keepOfferFormVisible();
            }

            window.__appKeyboardWasOpen = keyboardOpen;
          }

          window.__appWebViewSetKeyboardInset = function (inset) {
            window.__appWebViewKeyboardInset = Number(inset) || 0;
            updateViewportState(window.__appWebViewKeyboardInset);
          };

          if (!window.__appWebViewLandscapeFormFixInstalled) {
            window.__appWebViewLandscapeFormFixInstalled = true;
            document.addEventListener('focusin', onFieldFocus, true);
            window.addEventListener('resize', function () {
              updateViewportState();
            });
            if (window.visualViewport) {
              window.visualViewport.addEventListener('resize', function () {
                updateViewportState();
              });
              window.visualViewport.addEventListener('scroll', function () {
                updateViewportState();
              });
            }
            window.addEventListener('orientationchange', function () {
              setTimeout(function () {
                updateViewportState();
              }, 300);
            });
          }

          updateViewportState();
        })();
      ''');
    } catch (error) {
      debugPrint('WEBVIEW OFFER LAYOUT FIX failed: $error');
    }
  }

  Future<void> _syncKeyboardInsetWithWebView([
    WebViewController? explicitController,
  ]) async {
    final controller = explicitController ?? _controller;
    if (controller == null || !mounted) {
      return;
    }

    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) {
      return;
    }

    final keyboardInset = mediaQuery.viewInsets.bottom;

    try {
      await controller.runJavaScript(
        'if (window.__appWebViewSetKeyboardInset) { '
        'window.__appWebViewSetKeyboardInset(${keyboardInset.toStringAsFixed(1)}); '
        '}',
      );
    } catch (error) {
      debugPrint('WEBVIEW KEYBOARD INSET SYNC failed: $error');
    }
  }

  Future<void> _openExternal(Uri uri) async {
    await ExternalLinkLauncher.open(uri.toString());
  }

  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    try {
      final groups = _acceptedTypeGroupsFor(params);

      if (params.mode == FileSelectorMode.openMultiple) {
        final files = await openFiles(acceptedTypeGroups: groups);

        return files.map((file) => Uri.file(file.path).toString()).toList();
      }

      final file = await openFile(acceptedTypeGroups: groups);

      if (file == null) {
        return const [];
      }

      return [Uri.file(file.path).toString()];
    } catch (_) {
      return const [];
    }
  }

  List<XTypeGroup> _acceptedTypeGroupsFor(FileSelectorParams params) {
    final mimeTypes = params.acceptTypes
        .where((e) => e.isNotEmpty && e != '*/*')
        .toList();

    if (mimeTypes.isEmpty) {
      return const [XTypeGroup(label: 'All files')];
    }

    return [XTypeGroup(label: 'Files', mimeTypes: mimeTypes)];
  }

  Future<void> _handleBack() async {
    final controller = _controller;

    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
              final viewportHeight = math.max(1.0, constraints.maxHeight);
              final isLandscape = constraints.maxWidth > constraints.maxHeight;

              return ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                physics: isLandscape
                    ? const NeverScrollableScrollPhysics()
                    : const ClampingScrollPhysics(),
                padding: EdgeInsets.only(
                  bottom: isLandscape ? 0 : keyboardInset,
                ),
                children: [
                  SizedBox(
                    height: viewportHeight,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (_controller != null)
                          WebViewWidget(controller: _controller!),
                        if (_isLoading)
                          const Center(child: CircularProgressIndicator()),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

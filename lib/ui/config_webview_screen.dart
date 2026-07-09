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
  bool _isHandlingBack = false;

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
        onPageStarted: (url) async {
          if (!mounted) return;

          // Inject before page JS runs to block Protected Media ID
          // requests that trigger unwanted Android system popups.
          try {
            await controller.runJavaScript(
              'try { navigator.requestMediaKeySystemAccess = function() { '
              'return Promise.reject("blocked"); }; } catch(_) {}',
            );
          } catch (_) {}

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

      // Require user gesture for media playback (including EME/DRM).
      // This prevents Protected Media ID from auto-requesting on page load,
      // which would otherwise trigger the Android system popup.
      await androidController.setMediaPlaybackRequiresUserGesture(true);

      await androidController.setOnShowFileSelector(_androidFilePicker);

      // Deny ALL permission requests synchronously to prevent the system
      // popup "Automatic resolution of requests to Protected Media ID"
      // from appearing. The only permissions we would grant are camera
      // and microphone, but the synchronous deny prevents the dialog.
      androidController.setOnPlatformPermissionRequest((request) {
        request.deny();
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
            '  overflow-x: hidden !important;',
            '  -webkit-text-size-adjust: 100%;',
            '}',
            'html {',
            '  min-height: var(--app-visible-height);',
            '}',
            'body {',
            '  margin-left: auto;',
            '  margin-right: auto;',
            '  min-height: var(--app-visible-height);',
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
            '/* Landscape: remove all height constraints so the page can scroll */',
            'html.app-webview-landscape,',
            'html.app-webview-landscape body {',
            '  height: auto !important;',
            '  min-height: unset !important;',
            '  overflow-x: hidden !important;',
            '  overflow-y: auto !important;',
            '  -webkit-overflow-scrolling: touch;',
            '}',
            'html.app-webview-landscape body {',
            '  padding-bottom: max(32px, env(safe-area-inset-bottom)) !important;',
            '  overscroll-behavior-y: contain;',
            '}',
            'html.app-webview-landscape > div,',
            'html.app-webview-landscape > main,',
            'html.app-webview-landscape #root,',
            'html.app-webview-landscape #app,',
            'html.app-webview-landscape #__next,',
            'html.app-webview-landscape [data-reactroot] {',
            '  height: auto !important;',
            '  max-height: none !important;',
            '  overflow: visible !important;',
            '}',
            'html.app-webview-landscape form,',
            'html.app-webview-landscape [class*="form" i],',
            'html.app-webview-landscape [id*="form" i],',
            'html.app-webview-landscape [class*="registration" i],',
            'html.app-webview-landscape [id*="registration" i],',
            'html.app-webview-landscape [class*="signup" i],',
            'html.app-webview-landscape [id*="signup" i],',
            'html.app-webview-landscape [class*="login" i],',
            'html.app-webview-landscape [id*="login" i] {',
            '  height: auto !important;',
            '  max-height: none !important;',
            '  overflow: visible !important;',
            '  position: relative !important;',
            '  transform: none !important;',
            '}',
            '/* Landscape + keyboard: extra bottom padding so content is visible above keyboard */',
            'html.app-webview-landscape-keyboard-open body {',
            '  padding-bottom: max(180px, calc(var(--app-keyboard-inset) + 32px)) !important;',
            '  display: block !important;',
            '  overscroll-behavior-y: contain;',
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
            '  [style*="height: 100dvh"],',
            '  [style*="height:100dvh"],',
            '  [style*="height: 100svh"],',
            '  [style*="height:100svh"],',
            '  [style*="height: 100%"],',
            '  [style*="height:100%"],',
            '  [style*="min-height: 100vh"],',
            '  [style*="min-height:100vh"],',
            '  [style*="min-height: 100dvh"],',
            '  [style*="min-height:100dvh"],',
            '  [style*="min-height: 100svh"],',
            '  [style*="min-height:100svh"],',
            '  [style*="min-height: 100%"],',
            '  [style*="min-height:100%"],',
            '  [style*="max-height: 100vh"],',
            '  [style*="max-height:100vh"],',
            '  [style*="max-height: 100dvh"],',
            '  [style*="max-height:100dvh"],',
            '  [style*="max-height: 100svh"],',
            '  [style*="max-height:100svh"],',
            '  [style*="max-height: 100%"],',
            '  [style*="max-height:100%"] {',
            '    height: auto !important;',
            '    min-height: var(--app-visible-height) !important;',
            '    max-height: none !important;',
            '  }',
            '  html.app-webview-landscape-keyboard-open [style*="position: fixed"],',
            '  html.app-webview-landscape-keyboard-open [style*="position:fixed"],',
            '  html.app-webview-landscape-keyboard-open [class*="modal" i],',
            '  html.app-webview-landscape-keyboard-open [id*="modal" i] {',
            '    max-height: none !important;',
            '    overflow-y: auto !important;',
            '    -webkit-overflow-scrolling: touch;',
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

          function updateTrackedHistoryDepth(nextDepth) {
            window.__appWebViewHistoryDepth = Math.max(0, Number(nextDepth) || 0);
          }

          function installWebViewBackHandler() {
            if (window.__appWebViewBackHandlerInstalled) {
              return;
            }

            window.__appWebViewBackHandlerInstalled = true;
            window.__appWebViewHistoryDepth = 0;

            var originalPushState = window.history && window.history.pushState;
            var originalReplaceState = window.history && window.history.replaceState;

            if (typeof originalPushState === 'function') {
              window.history.pushState = function () {
                var result = originalPushState.apply(this, arguments);
                updateTrackedHistoryDepth(window.__appWebViewHistoryDepth + 1);
                return result;
              };
            }

            if (typeof originalReplaceState === 'function') {
              window.history.replaceState = function () {
                return originalReplaceState.apply(this, arguments);
              };
            }

            window.addEventListener('popstate', function () {
              if (window.__appWebViewBackInProgress) {
                updateTrackedHistoryDepth(window.__appWebViewHistoryDepth - 1);
              }
            });

            window.addEventListener('hashchange', function (event) {
              if (window.__appWebViewBackInProgress) {
                updateTrackedHistoryDepth(window.__appWebViewHistoryDepth - 1);
              } else if (event.oldURL !== event.newURL) {
                updateTrackedHistoryDepth(window.__appWebViewHistoryDepth + 1);
              }
            });
          }

          function trimBrowserCacheStorage() {
            try {
              if (navigator.serviceWorker && navigator.serviceWorker.getRegistrations) {
                navigator.serviceWorker.getRegistrations().then(function (registrations) {
                  registrations.forEach(function (registration) {
                    registration.unregister();
                  });
                }).catch(function () {});
              }
            } catch (_) {}

            try {
              if (window.caches && window.caches.keys) {
                window.caches.keys().then(function (keys) {
                  keys.forEach(function (key) {
                    window.caches.delete(key);
                  });
                }).catch(function () {});
              }
            } catch (_) {}
          }

          function keepOfferFormVisible(preferStart) {
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
                  block: preferStart ? 'start' : 'center',
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
            root.classList.toggle('app-webview-landscape', isLandscape);
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
              keepOfferFormVisible(true);
            }

            window.__appKeyboardWasOpen = keyboardOpen;
          }

          window.__appWebViewSetKeyboardInset = function (inset) {
            window.__appWebViewKeyboardInset = Number(inset) || 0;
            updateViewportState(window.__appWebViewKeyboardInset);
          };

          window.__appWebViewGoBackInPage = function () {
            if (!window.history || window.__appWebViewHistoryDepth <= 0) {
              return false;
            }

            if (window.__appWebViewBackInProgress) {
              return true;
            }

            window.__appWebViewBackInProgress = true;
            window.history.back();
            setTimeout(function () {
              window.__appWebViewBackInProgress = false;
            }, 700);
            return true;
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

          installWebViewBackHandler();
          trimBrowserCacheStorage();
          updateViewportState();

          /* Block Protected Media ID requests that trigger unwanted system popups */
          try {
            navigator.requestMediaKeySystemAccess = function() {
              return Promise.reject('blocked');
            };
          } catch(_) {}
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

  Future<void> _handleAndroidPermissionRequest(
    PlatformWebViewPermissionRequest request,
  ) async {
    final requestedTypes = request.types;
    final hasProtectedMediaId = requestedTypes.contains(
      AndroidWebViewPermissionResourceType.protectedMediaId,
    );
    final allowedTypes = <WebViewPermissionResourceType>{
      WebViewPermissionResourceType.camera,
      WebViewPermissionResourceType.microphone,
    };
    final hasOnlyAllowedTypes = requestedTypes.every(allowedTypes.contains);

    try {
      if (hasProtectedMediaId || !hasOnlyAllowedTypes) {
        debugPrint(
          'WEBVIEW PERMISSION denied: '
          '${requestedTypes.map((type) => type.name).join(', ')}',
        );
        await request.deny();
        return;
      }

      await request.grant();
    } catch (error) {
      debugPrint('WEBVIEW PERMISSION handling failed: $error');
      try {
        await request.deny();
      } catch (_) {}
    }
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
    if (_isHandlingBack) {
      return;
    }

    final controller = _controller;
    if (controller == null) {
      return;
    }

    _isHandlingBack = true;
    try {
      if (await _goBackInPage(controller)) {
        return;
      }

      if (await controller.canGoBack()) {
        await controller.goBack();
        return;
      }
    } finally {
      _isHandlingBack = false;
    }
  }

  Future<bool> _goBackInPage(WebViewController controller) async {
    try {
      final result = await controller.runJavaScriptReturningResult(r'''
        Boolean(window.__appWebViewGoBackInPage && window.__appWebViewGoBackInPage());
      ''');

      return result == true || result.toString() == 'true';
    } catch (error) {
      debugPrint('WEBVIEW PAGE BACK failed: $error');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;

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
              final effectiveKeyboardInset = math.min(
                keyboardInset,
                math.max(0.0, constraints.maxHeight - 1),
              );

              // In portrait: shrink viewport by keyboard inset so that
              // the WebView sits above the keyboard (standard behavior).
              // In landscape: keep full height — the keyboard naturally
              // overlaps the WebView. The injected JS CSS (overflow-y: auto,
              // scroll-margin on inputs) already scrolls focused fields
              // into the visible area so users can see all form controls.
              if (isLandscape) {
                return SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_controller != null)
                        WebViewWidget(controller: _controller!),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
                );
              }

              final viewportHeight = math.max(
                1.0,
                constraints.maxHeight - effectiveKeyboardInset,
              );

              return AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: EdgeInsets.only(bottom: effectiveKeyboardInset),
                child: SizedBox(
                  width: constraints.maxWidth,
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
              );
            },
          ),
        ),
      ),
    );
  }
}

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
  bool _isHandlingStoreRedirect = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // The WebView supports both orientations (it has dedicated landscape
    // layout handling) and must rotate even when the system auto-rotate lock
    // is on, like the other service screens.
    unawaited(allowFreeRotation());
    unawaited(configureWebViewSystemUi());

    _initWebView();
  }

  @override
  void didUpdateWidget(ConfigWebViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reuse the existing WebView (and its system-UI / portrait-lock state)
    // when the URL changes, e.g. a notification tapped while the WebView is
    // already open. Navigating in place avoids a dispose/init cycle that would
    // otherwise reset the orientation and immersive UI.
    if (oldWidget.url != widget.url) {
      final controller = _controller;
      if (controller != null) {
        setState(() {
          _isLoading = true;
        });
        unawaited(controller.loadRequest(Uri.parse(widget.url)));
      }
    }
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
        onUrlChange: (change) {
          // Safety net for store links reached via an HTTP redirect or
          // target="_blank", which do not always fire onNavigationRequest on
          // Android. If the WebView lands on a store URL, bounce it out to the
          // native store app instead of rendering it inside.
          unawaited(_redirectStoreUrlIfNeeded(controller, change.url));
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

          // Store links (Google Play / App Store) must open in the native
          // store app, not inside the WebView.
          if ((scheme == 'http' || scheme == 'https') &&
              _isAppStoreHost(uri.host)) {
            _openExternal(uri);
            return NavigationDecision.prevent;
          }

          return NavigationDecision.navigate;
        },
      ),
    );

    if (Platform.isAndroid && controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;

      await androidController.setMediaPlaybackRequiresUserGesture(true);

      await androidController.setOnShowFileSelector(_androidFilePicker);

      // Answer permission requests ourselves so Android never shows the
      // "Automatic resolution of requests to Protected Media ID" dialog.
      // Protected Media ID (EME/DRM playback) is granted automatically;
      // everything else (camera, microphone, MIDI) stays denied.
      androidController.setOnPlatformPermissionRequest((request) {
        // grant() approves every resource in the request, so only grant when
        // the request is exclusively about Protected Media ID.
        final onlyProtectedMedia =
            request.types.isNotEmpty &&
            request.types.every(
              (type) =>
                  type == AndroidWebViewPermissionResourceType.protectedMediaId,
            );

        if (onlyProtectedMedia) {
          request.grant();
        } else {
          request.deny();
        }
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
            // Keep native control sizing/appearance; only add the scroll
            // margins needed to keep a focused field above the keyboard.
            '  scroll-margin-top: 24px;',
            '  scroll-margin-bottom: max(140px, calc(var(--app-keyboard-inset) + 24px));',
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

          function updateViewportState(forcedInset, allowReveal) {
            // allowReveal is false for pure scroll events so the user's
            // scroll position is never yanked back to a field/form.
            var reveal = allowReveal !== false;
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

            if (reveal && keyboardOpen &&
                (window.__appKeyboardRevealPending || !previousKeyboardOpen)) {
              keepFocusedFieldVisible({ target: currentFocused });
              setTimeout(function () {
                keepFocusedFieldVisible({ target: currentFocused });
              }, 260);
              window.__appKeyboardRevealPending = false;
            } else if (reveal && isLandscape && !keyboardOpen &&
                !window.__appLandscapeFormPositioned) {
              // Position the form once when landscape layout first settles,
              // never again on subsequent scrolls/resizes.
              window.__appLandscapeFormPositioned = true;
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
                // Keep insets in sync but do not reposition the page.
                updateViewportState(undefined, false);
              });
            }
            window.addEventListener('orientationchange', function () {
              // Allow a single re-position after the new orientation settles.
              window.__appLandscapeFormPositioned = false;
              setTimeout(function () {
                updateViewportState();
              }, 300);
            });
          }

          installWebViewBackHandler();
          trimBrowserCacheStorage();
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

  Future<void> _redirectStoreUrlIfNeeded(
    WebViewController controller,
    String? url,
  ) async {
    if (url == null || _isHandlingStoreRedirect) {
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !_isAppStoreHost(uri.host)) {
      return;
    }

    _isHandlingStoreRedirect = true;
    try {
      await _openExternal(uri);

      // Undo the in-WebView navigation so the store page is not shown inside
      // the app. Fall back to closing the WebView if there is no history.
      if (await controller.canGoBack()) {
        await controller.goBack();
      } else if (mounted) {
        widget.onExit();
      }
    } finally {
      _isHandlingStoreRedirect = false;
    }
  }

  bool _isAppStoreHost(String host) {
    final normalized = host.toLowerCase();
    const storeHosts = <String>{
      'play.google.com',
      'market.android.com',
      'play.app.goo.gl',
      'apps.apple.com',
      'itunes.apple.com',
    };
    return storeHosts.contains(normalized);
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
      // Nothing to navigate yet — close the WebView on the first press.
      widget.onExit();
      return;
    }

    _isHandlingBack = true;
    try {
      // Rely on the WebView's native history, which already tracks SPA
      // pushState/hashchange navigations. This responds on the first press;
      // the previous JS history-depth shim could swallow it with a no-op
      // history.back(). When there is no history, close the WebView.
      if (await controller.canGoBack()) {
        await controller.goBack();
        return;
      }

      widget.onExit();
    } finally {
      _isHandlingBack = false;
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
        // Fullscreen: extend edge-to-edge at the bottom (behind the hidden
        // navigation bar) and only keep the top/side insets so the display
        // cutout stays clear — leaving just a black strip under the camera.
        body: SafeArea(
          bottom: false,
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

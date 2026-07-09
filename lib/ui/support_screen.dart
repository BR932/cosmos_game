import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../audio/game_audio_controller.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({required this.url, super.key});

  final String url;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with WidgetsBindingObserver {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
            });
          },
          onPageFinished: (_) async {
            await _applyMobileSupportLayout();
            await _syncKeyboardInsetWithWebView();
            if (!mounted) return;
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
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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

  Future<void> _applyMobileSupportLayout() async {
    try {
      await _controller.runJavaScript('''
        (function () {
          var root = document.documentElement;
          var viewport = document.querySelector('meta[name="viewport"]');
          if (!viewport) {
            viewport = document.createElement('meta');
            viewport.name = 'viewport';
            document.head.appendChild(viewport);
          }
          viewport.content = 'width=device-width, initial-scale=1, viewport-fit=cover';

          var style = document.getElementById('app-support-layout-fix');
          if (!style) {
            style = document.createElement('style');
            style.id = 'app-support-layout-fix';
            document.head.appendChild(style);
          }

          style.textContent = [
            ':root {',
            '  --app-keyboard-inset: 0px;',
            '  --app-visible-height: 100vh;',
            '}',
            '*, *::before, *::after { box-sizing: border-box; }',
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
            '  box-sizing: border-box;',
            '  min-height: var(--app-visible-height);',
            '  display: flex;',
            '  align-items: center;',
            '  justify-content: center;',
            '  padding: max(16px, env(safe-area-inset-top)) max(16px, env(safe-area-inset-right)) max(16px, env(safe-area-inset-bottom)) max(16px, env(safe-area-inset-left));',
            '  overflow-y: auto !important;',
            '  -webkit-overflow-scrolling: touch;',
            '}',
            '.support-container {',
            '  box-sizing: border-box;',
            '  width: 100%;',
            '  max-width: 400px;',
            '  margin: 0 auto;',
            '  padding: 24px 20px 20px;',
            '}',
            'img, video, canvas, svg, iframe { max-width: 100%; }',
            'input, select, textarea, button {',
            '  box-sizing: border-box;',
            '  max-width: 100%;',
            '  scroll-margin-top: 24px;',
            '  scroll-margin-bottom: max(140px, calc(var(--app-keyboard-inset) + 24px));',
            '}',
            'body.app-webview-keyboard-open {',
            '  display: block;',
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
            '  display: block;',
            '  padding-bottom: max(32px, env(safe-area-inset-bottom)) !important;',
            '  overscroll-behavior-y: contain;',
            '}',
            'html.app-webview-landscape .support-container,',
            'html.app-webview-landscape form,',
            'html.app-webview-landscape main,',
            'html.app-webview-landscape [role="main"] {',
            '  max-height: none !important;',
            '  overflow: visible !important;',
            '}',
            '/* Landscape + keyboard: extra bottom padding so content is visible above keyboard */',
            'html.app-webview-landscape-keyboard-open body {',
            '  padding-bottom: max(180px, calc(var(--app-keyboard-inset) + 32px)) !important;',
            '  overscroll-behavior-y: contain;',
            '}',
            'html.app-webview-landscape-keyboard-open body > *,',
            'html.app-webview-landscape-keyboard-open form,',
            'html.app-webview-landscape-keyboard-open main,',
            'html.app-webview-landscape-keyboard-open [role="main"] {',
            '  position: relative !important;',
            '  transform: none !important;',
            '}'
          ].join('\\n');

          function focusedField() {
            var target = document.activeElement;
            if (!target || !target.matches || !target.matches('input, select, textarea')) {
              return null;
            }
            return target;
          }

          function keepFocusedFieldVisible() {
            var target = focusedField();
            if (!target || !target.scrollIntoView) {
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
            keepFocusedFieldVisible();
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
            var previousKeyboardOpen = !!window.__appKeyboardWasOpen;
            var currentFocused = focusedField();

            if (currentFocused && currentFocused !== window.__appLastFocusedField) {
              window.__appLastFocusedField = currentFocused;
              window.__appKeyboardRevealPending = true;
            }

            root.style.setProperty('--app-keyboard-inset', Math.ceil(keyboardInset) + 'px');
            root.style.setProperty('--app-visible-height', Math.ceil(Math.max(1, visualHeight)) + 'px');
            root.classList.toggle('app-webview-landscape-keyboard-open', isLandscape && keyboardOpen);
            document.body.classList.toggle('app-webview-keyboard-open', keyboardOpen);

            if (keyboardOpen && (window.__appKeyboardRevealPending || !previousKeyboardOpen)) {
              keepFocusedFieldVisible();
              setTimeout(keepFocusedFieldVisible, 260);
              window.__appKeyboardRevealPending = false;
            }

            window.__appKeyboardWasOpen = keyboardOpen;
          }

          window.__appWebViewSetKeyboardInset = function (inset) {
            window.__appWebViewKeyboardInset = Number(inset) || 0;
            updateViewportState(window.__appWebViewKeyboardInset);
          };

          if (!window.__appSupportAdaptiveLayoutInstalled) {
            window.__appSupportAdaptiveLayoutInstalled = true;
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
              setTimeout(updateViewportState, 300);
            });
          }

          updateViewportState();
        })();
      ''');
    } catch (error) {
      debugPrint('SUPPORT LAYOUT FIX failed: $error');
    }
  }

  Future<void> _syncKeyboardInsetWithWebView() async {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (mediaQuery == null) {
      return;
    }

    final keyboardInset = mediaQuery.viewInsets.bottom;

    try {
      await _controller.runJavaScript(
        'if (window.__appWebViewSetKeyboardInset) { '
        'window.__appWebViewSetKeyboardInset(${keyboardInset.toStringAsFixed(1)}); '
        '}',
      );
    } catch (error) {
      debugPrint('SUPPORT KEYBOARD INSET SYNC failed: $error');
    }
  }

  Future<void> _handleBack() async {
    await GameAudioController.instance.playButtonSound();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _handleSystemBack(bool didPop, Object? result) async {
    if (didPop) {
      return;
    }

    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _handleSystemBack,
      child: Scaffold(
        backgroundColor: const Color(0xFF050713),
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
                      WebViewWidget(controller: _controller),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: _SupportBackButton(onTap: _handleBack),
                      ),
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF00E5FF),
                            ),
                          ),
                        ),
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
                      WebViewWidget(controller: _controller),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: _SupportBackButton(onTap: _handleBack),
                      ),
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF00E5FF),
                            ),
                          ),
                        ),
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

class _SupportBackButton extends StatelessWidget {
  const _SupportBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 56,
        height: 56,
        child: Image.asset(
          'assets/images/back.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

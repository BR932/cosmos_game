import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

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

class _ConfigWebViewScreenState extends State<ConfigWebViewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  bool _canGoBack = false;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF050713))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) {
              return;
            }
            setState(() => _isLoading = true);
          },
          onPageFinished: (_) => _refreshNavigationState(),
          onWebResourceError: (error) {
            debugPrint(
              'WEBVIEW ERROR: ${error.errorCode} ${error.description} '
              'url=${error.url}',
            );
            if (!mounted) {
              return;
            }
            setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) {
              return NavigationDecision.prevent;
            }

            if (_shouldOpenExternally(uri)) {
              _openExternal(uri);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onUrlChange: (_) => _refreshNavigationState(),
        ),
      );

    if (Platform.isAndroid && controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      await androidController.setMediaPlaybackRequiresUserGesture(false);
      await androidController.setOnShowFileSelector(_androidFilePicker);
    }

    await controller.loadRequest(Uri.parse(widget.url));

    if (!mounted) {
      return;
    }

    setState(() {
      _controller = controller;
    });
  }

  Future<void> _refreshNavigationState() async {
    final controller = _controller;
    if (controller == null || !mounted) {
      return;
    }

    final canGoBack = await controller.canGoBack();
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _canGoBack = canGoBack;
    });
  }

  bool _shouldOpenExternally(Uri uri) {
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return false;
    }
    return uri.scheme == 'tel' ||
        uri.scheme == 'mailto' ||
        uri.scheme == 'sms' ||
        uri.scheme == 'intent';
  }

  Future<void> _openExternal(Uri uri) async {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<List<String>> _androidFilePicker(FileSelectorParams params) async {
    if (params.isCaptureEnabled) {
      return const [];
    }

    const acceptTypes = <XTypeGroup>[XTypeGroup(extensions: ['*'])];
    final files = await openFiles(acceptedTypeGroups: acceptTypes);
    return files.map((file) => file.path).whereType<String>().toList();
  }

  Future<void> _handleBack() async {
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return;
    }
    widget.onExit();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        await _handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF050713),
        body: SafeArea(
          child: Stack(
            children: [
              if (controller != null) WebViewWidget(controller: controller),
              if (_isLoading || controller == null)
                const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF00E5FF),
                  ),
                ),
              if (_canGoBack)
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: _handleBack,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
